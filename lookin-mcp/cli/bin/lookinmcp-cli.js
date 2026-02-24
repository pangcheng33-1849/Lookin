#!/usr/bin/env node

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const CLI_VERSION = '0.1.0';
const DEFAULT_URL = process.env.LOOKIN_MCP_URL || 'http://127.0.0.1:4010/mcp';
const DEFAULT_TIMEOUT_SEC = 15;
const DEFAULT_PROTOCOL_VERSION = '2025-06-18';

const COMMANDS = {
  health: {
    mcpTool: 'lookin.health',
    description: 'Check MCP runtime and current Lookin session health.',
    example: 'lookinmcp-cli health',
    parseArgs: parseNoArgs,
    buildArgs: () => ({})
  },
  get_selected_view_context: {
    mcpTool: 'lookin.get_selected_view_context',
    description: 'Get dashboard attributes and hierarchy context of selected iOS view node.',
    example: 'lookinmcp-cli get_selected_view_context --children-depth 1',
    parseArgs: parseGetSelectedViewContextArgs,
    buildArgs: (opts) => {
      const args = {};
      if (typeof opts.childrenDepth === 'number') {
        args.childrenDepth = opts.childrenDepth;
      }
      return args;
    }
  },
  set_requirement_items: {
    mcpTool: 'lookin.set_requirement_items',
    description: 'Append/remove requirement items for Code Info management board.',
    example:
      "lookinmcp-cli set_requirement_items --operation append --items-json '[{\"requirementId\":\"R-1\",\"description\":\"点赞按钮\",\"codeInfo\":\"DUXDiggButton\"}]'",
    parseArgs: parseSetRequirementItemsArgs,
    buildArgs: (opts) => ({
      operation: opts.operation,
      items: opts.items
    })
  },
  get_requirement_code_info: {
    mcpTool: 'lookin.get_requirement_code_info',
    description: 'Read current requirement/code-info list from Lookin MCP store.',
    example: 'lookinmcp-cli get_requirement_code_info',
    parseArgs: parseNoArgs,
    buildArgs: () => ({})
  },
  capture_selected_view_screenshot: {
    mcpTool: 'lookin.capture_selected_view_screenshot',
    description: 'Capture screenshot for current selected iOS view node.',
    example: 'lookinmcp-cli capture_selected_view_screenshot --format png --output /tmp/selected.png',
    parseArgs: parseCaptureScreenshotArgs,
    buildArgs: (opts) => ({
      format: opts.format
    })
  }
};

class CLIError extends Error {
  constructor(code, message, details) {
    super(message);
    this.name = 'CLIError';
    this.code = code;
    this.details = details;
  }
}

class MCPClient {
  constructor(options) {
    this.url = options.url;
    this.timeoutMs = Math.max(1000, Math.floor(options.timeoutSec * 1000));
    this.protocolVersion = DEFAULT_PROTOCOL_VERSION;
    this.sessionId = null;
    this.initialized = false;
    this.nextId = 1;
  }

  async ensureInitialized() {
    if (this.initialized) {
      return;
    }

    const initializeResult = await this._request('initialize', {
      protocolVersion: this.protocolVersion,
      capabilities: {},
      clientInfo: {
        name: 'lookinmcp-cli',
        version: CLI_VERSION
      }
    });

    if (initializeResult && typeof initializeResult.protocolVersion === 'string') {
      this.protocolVersion = initializeResult.protocolVersion;
    }

    await this._request('notifications/initialized', {}, { notification: true });
    this.initialized = true;
  }

  async callTool(toolName, argumentsObject) {
    await this.ensureInitialized();

    const result = await this._request('tools/call', {
      name: toolName,
      arguments: argumentsObject || {}
    });

    if (result && result.isError) {
      const structured = isObject(result.structuredContent) ? result.structuredContent : {};
      const errorDetails = isObject(structured.error) ? structured.error : structured;
      throw new CLIError(
        'LOOKINMCP_CLI_TOOL_ERROR',
        stringOrDefault(errorDetails.message, `Tool failed: ${toolName}`),
        errorDetails
      );
    }

    if (isObject(result) && isObject(result.structuredContent)) {
      return result.structuredContent;
    }

    return result;
  }

  async _request(method, params, options) {
    const notification = Boolean(options && options.notification);
    const payload = {
      jsonrpc: '2.0',
      method: method
    };
    if (params !== undefined) {
      payload.params = params;
    }
    if (!notification) {
      payload.id = this.nextId++;
    }

    const headers = {
      'Content-Type': 'application/json',
      'MCP-Protocol-Version': this.protocolVersion
    };
    if (this.sessionId) {
      headers['Mcp-Session-Id'] = this.sessionId;
    }

    let response;
    try {
      response = await fetch(this.url, {
        method: 'POST',
        headers: headers,
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(this.timeoutMs)
      });
    } catch (error) {
      throw new CLIError('LOOKINMCP_CLI_TRANSPORT_ERROR', 'Failed to reach MCP endpoint.', {
        reason: error && error.message ? error.message : String(error),
        url: this.url,
        method: method
      });
    }

    const returnedSessionId = response.headers.get('mcp-session-id');
    if (returnedSessionId) {
      this.sessionId = returnedSessionId;
    }

    const text = await response.text();
    if (!text.trim()) {
      if (notification) {
        return {};
      }
      throw new CLIError('LOOKINMCP_CLI_PROTOCOL_ERROR', 'MCP response body is empty.', {
        status: response.status,
        method: method
      });
    }

    let json;
    try {
      json = JSON.parse(text);
    } catch (error) {
      throw new CLIError('LOOKINMCP_CLI_PROTOCOL_ERROR', 'MCP response is not valid JSON.', {
        status: response.status,
        method: method,
        raw: text
      });
    }

    if (isObject(json) && isObject(json.error)) {
      const rpcError = json.error;
      const data = isObject(rpcError.data) ? rpcError.data : {};
      throw new CLIError(
        'LOOKINMCP_CLI_MCP_ERROR',
        stringOrDefault(rpcError.message, 'MCP returned error response.'),
        Object.assign(
          {
            rpcCode: rpcError.code,
            method: method,
            status: response.status
          },
          data
        )
      );
    }

    if (notification) {
      if (!response.ok && response.status !== 202) {
        throw new CLIError('LOOKINMCP_CLI_PROTOCOL_ERROR', 'Notification request failed.', {
          status: response.status,
          method: method,
          response: json
        });
      }
      return {};
    }

    if (!isObject(json) || !Object.prototype.hasOwnProperty.call(json, 'result')) {
      throw new CLIError('LOOKINMCP_CLI_PROTOCOL_ERROR', 'MCP response missing result field.', {
        status: response.status,
        method: method,
        response: json
      });
    }

    return json.result;
  }
}

function printRootHelp() {
  const lines = [
    'lookinmcp-cli - Local CLI for Lookin MCP tools',
    '',
    'Usage:',
    '  lookinmcp-cli [global-options] <command> [command-options]',
    '',
    'Global options:',
    `  --url <url>         MCP endpoint URL (default: ${DEFAULT_URL})`,
    `  --timeout <sec>     Request timeout in seconds (default: ${DEFAULT_TIMEOUT_SEC})`,
    '  -h, --help          Show help',
    '',
    'Commands:',
    '  health                               -> lookin.health',
    '  get_selected_view_context            -> lookin.get_selected_view_context',
    '  set_requirement_items                -> lookin.set_requirement_items',
    '  get_requirement_code_info            -> lookin.get_requirement_code_info',
    '  capture_selected_view_screenshot     -> lookin.capture_selected_view_screenshot',
    '',
    'Run `lookinmcp-cli <command> --help` for command details.'
  ];
  process.stdout.write(lines.join('\n') + '\n');
}

function printCommandHelp(commandName) {
  const command = COMMANDS[commandName];
  if (!command) {
    throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', `Unknown command: ${commandName}`);
  }

  const lines = [
    `Command: ${commandName}`,
    `MCP tool: ${command.mcpTool}`,
    `Description: ${command.description}`,
    '',
    `Usage: lookinmcp-cli [global-options] ${commandName} [command-options]`,
    '',
    'Command options:'
  ];

  if (commandName === 'get_selected_view_context') {
    lines.push('  --children-depth <int>    Optional depth of children tree (>= 0).');
  } else if (commandName === 'set_requirement_items') {
    lines.push('  --operation <append|remove>   Required operation.');
    lines.push("  --items-json '<json>'          Required JSON array for items.");
  } else if (commandName === 'capture_selected_view_screenshot') {
    lines.push('  --format <png>            Screenshot format, only png is supported.');
    lines.push('  --output <path>           Optional output file path (copy from MCP result path).');
  } else {
    lines.push('  (no command-specific options)');
  }

  lines.push('  -h, --help                Show command help.');
  lines.push('');
  lines.push('Example:');
  lines.push(`  ${command.example}`);
  lines.push('');
  lines.push('Errors:');
  lines.push('  Returns JSON error to stderr with code/message/details.');

  process.stdout.write(lines.join('\n') + '\n');
}

function parseCLI(argv) {
  let url = DEFAULT_URL;
  let timeoutSec = DEFAULT_TIMEOUT_SEC;

  let index = 0;
  while (index < argv.length) {
    const token = argv[index];
    if (token === '--help' || token === '-h') {
      return { action: 'root-help' };
    }
    if (token === '--url') {
      const value = argv[index + 1];
      if (!value) {
        throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', 'Missing value for --url.');
      }
      url = value;
      index += 2;
      continue;
    }
    if (token.startsWith('--url=')) {
      url = token.slice('--url='.length);
      index += 1;
      continue;
    }
    if (token === '--timeout') {
      const value = argv[index + 1];
      if (!value) {
        throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', 'Missing value for --timeout.');
      }
      timeoutSec = parseTimeout(value);
      index += 2;
      continue;
    }
    if (token.startsWith('--timeout=')) {
      timeoutSec = parseTimeout(token.slice('--timeout='.length));
      index += 1;
      continue;
    }
    if (token.startsWith('-')) {
      throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', `Unknown global option: ${token}`);
    }

    const commandName = token;
    const commandArgs = argv.slice(index + 1);
    return {
      action: 'run-command',
      url: url,
      timeoutSec: timeoutSec,
      commandName: commandName,
      commandArgs: commandArgs
    };
  }

  return { action: 'root-help' };
}

function parseNoArgs(args, commandName) {
  if (args.length === 0) {
    return { help: false, options: {} };
  }
  if (args.length === 1 && (args[0] === '--help' || args[0] === '-h')) {
    return { help: true, options: {} };
  }
  throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', `Command ${commandName} does not accept options.`);
}

function parseGetSelectedViewContextArgs(args) {
  let childrenDepth;
  let index = 0;
  while (index < args.length) {
    const token = args[index];
    if (token === '--help' || token === '-h') {
      return { help: true, options: {} };
    }
    if (token === '--children-depth') {
      const value = args[index + 1];
      if (value === undefined) {
        throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', 'Missing value for --children-depth.');
      }
      childrenDepth = parseNonNegativeInt(value, '--children-depth');
      index += 2;
      continue;
    }
    if (token.startsWith('--children-depth=')) {
      childrenDepth = parseNonNegativeInt(token.slice('--children-depth='.length), '--children-depth');
      index += 1;
      continue;
    }
    throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', `Unknown option for get_selected_view_context: ${token}`);
  }

  return {
    help: false,
    options: {
      childrenDepth: childrenDepth
    }
  };
}

function parseSetRequirementItemsArgs(args) {
  let operation;
  let itemsJson;

  let index = 0;
  while (index < args.length) {
    const token = args[index];
    if (token === '--help' || token === '-h') {
      return { help: true, options: {} };
    }
    if (token === '--operation') {
      const value = args[index + 1];
      if (!value) {
        throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', 'Missing value for --operation.');
      }
      operation = value;
      index += 2;
      continue;
    }
    if (token.startsWith('--operation=')) {
      operation = token.slice('--operation='.length);
      index += 1;
      continue;
    }
    if (token === '--items-json') {
      const value = args[index + 1];
      if (!value) {
        throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', 'Missing value for --items-json.');
      }
      itemsJson = value;
      index += 2;
      continue;
    }
    if (token.startsWith('--items-json=')) {
      itemsJson = token.slice('--items-json='.length);
      index += 1;
      continue;
    }

    throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', `Unknown option for set_requirement_items: ${token}`);
  }

  if (operation !== 'append' && operation !== 'remove') {
    throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', 'set_requirement_items requires --operation append|remove.');
  }
  if (!itemsJson) {
    throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', 'set_requirement_items requires --items-json <json-array>.');
  }

  let parsedItems;
  try {
    parsedItems = JSON.parse(itemsJson);
  } catch (error) {
    throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', 'Invalid JSON for --items-json.', {
      reason: error && error.message ? error.message : String(error)
    });
  }

  if (!Array.isArray(parsedItems)) {
    throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', '--items-json must be a JSON array.');
  }

  return {
    help: false,
    options: {
      operation: operation,
      items: parsedItems
    }
  };
}

function parseCaptureScreenshotArgs(args) {
  let format = 'png';
  let output;

  let index = 0;
  while (index < args.length) {
    const token = args[index];
    if (token === '--help' || token === '-h') {
      return { help: true, options: {} };
    }
    if (token === '--format') {
      const value = args[index + 1];
      if (!value) {
        throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', 'Missing value for --format.');
      }
      format = value;
      index += 2;
      continue;
    }
    if (token.startsWith('--format=')) {
      format = token.slice('--format='.length);
      index += 1;
      continue;
    }
    if (token === '--output') {
      const value = args[index + 1];
      if (!value) {
        throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', 'Missing value for --output.');
      }
      output = value;
      index += 2;
      continue;
    }
    if (token.startsWith('--output=')) {
      output = token.slice('--output='.length);
      index += 1;
      continue;
    }
    throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', `Unknown option for capture_selected_view_screenshot: ${token}`);
  }

  return {
    help: false,
    options: {
      format: format,
      output: output
    }
  };
}

function parseNonNegativeInt(raw, optionName) {
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 0) {
    throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', `${optionName} must be a non-negative integer.`);
  }
  return value;
}

function parseTimeout(raw) {
  const value = Number(raw);
  if (!Number.isFinite(value) || value <= 0) {
    throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', '--timeout must be a positive number (seconds).');
  }
  return value;
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function stringOrDefault(value, fallback) {
  return typeof value === 'string' && value.length > 0 ? value : fallback;
}

function writeJSONToStdout(value) {
  process.stdout.write(JSON.stringify(value, null, 2) + '\n');
}

function writeErrorAndExit(error) {
  if (error instanceof CLIError) {
    writeJSONToStderr({
      ok: false,
      error: {
        code: error.code,
        message: error.message,
        details: error.details || {}
      }
    });
    process.exit(1);
  }

  writeJSONToStderr({
    ok: false,
    error: {
      code: 'LOOKINMCP_CLI_UNEXPECTED',
      message: error && error.message ? error.message : String(error),
      details: {}
    }
  });
  process.exit(1);
}

function writeJSONToStderr(value) {
  process.stderr.write(JSON.stringify(value, null, 2) + '\n');
}

async function maybeCopyScreenshotOutput(result, outputPathValue) {
  if (!outputPathValue) {
    return result;
  }
  if (!isObject(result) || typeof result.path !== 'string' || result.path.length === 0) {
    throw new CLIError('LOOKINMCP_CLI_OUTPUT_ERROR', 'Screenshot result does not include source path.', {
      result: result
    });
  }

  const source = path.resolve(result.path);
  const target = path.resolve(outputPathValue);

  if (!fs.existsSync(source)) {
    throw new CLIError('LOOKINMCP_CLI_OUTPUT_ERROR', 'Source screenshot path does not exist.', {
      source: source
    });
  }

  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(source, target);

  const copiedResult = Object.assign({}, result, {
    outputPath: target
  });
  return copiedResult;
}

async function main() {
  const parsed = parseCLI(process.argv.slice(2));

  if (parsed.action === 'root-help') {
    printRootHelp();
    return;
  }

  const command = COMMANDS[parsed.commandName];
  if (!command) {
    throw new CLIError('LOOKINMCP_CLI_BAD_ARGUMENT', `Unknown command: ${parsed.commandName}`);
  }

  const parsedCommand = command.parseArgs(parsed.commandArgs, parsed.commandName);
  if (parsedCommand.help) {
    printCommandHelp(parsed.commandName);
    return;
  }

  const client = new MCPClient({
    url: parsed.url,
    timeoutSec: parsed.timeoutSec
  });

  const toolArguments = command.buildArgs(parsedCommand.options);
  let result = await client.callTool(command.mcpTool, toolArguments);

  if (parsed.commandName === 'capture_selected_view_screenshot') {
    result = await maybeCopyScreenshotOutput(result, parsedCommand.options.output);
  }

  writeJSONToStdout(result);
}

main().catch(writeErrorAndExit);
