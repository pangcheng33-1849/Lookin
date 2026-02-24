# lookinmcp-cli

`lookinmcp-cli` is a local command-line wrapper for Lookin MCP tools.
Published package name: `@cheng-pang/lookinmcp-cli`

- Transport: HTTP JSON-RPC 2.0
- Default endpoint: `http://127.0.0.1:4010/mcp`
- Output: JSON (stdout)

## Usage

```bash
lookinmcp-cli [global-options] <command> [command-options]
```

### Global options

- `--url <url>`: MCP endpoint URL
- `--timeout <sec>`: request timeout in seconds
- `-h`, `--help`: show help

### Commands

- `health`
- `get_selected_view_context`
- `set_requirement_items`
- `get_requirement_code_info`
- `capture_selected_view_screenshot`

### Examples

```bash
npx @cheng-pang/lookinmcp-cli --help
npx @cheng-pang/lookinmcp-cli health
lookinmcp-cli health
lookinmcp-cli get_selected_view_context --children-depth 1
lookinmcp-cli get_requirement_code_info
lookinmcp-cli set_requirement_items --operation append --items-json '[{"requirementId":"R-1","description":"点赞按钮","codeInfo":"DUXDiggButton"}]'
lookinmcp-cli capture_selected_view_screenshot --format png --output /tmp/selected.png
```
