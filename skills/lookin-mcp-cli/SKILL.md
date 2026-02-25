---
name: lookin-mcp-cli
description: This skill should be used when the user asks to "通过lookinmcp-cli获取选中视图信息", "通过lookinmcp-cli找到自然语言描述的相关视图", "通过lookinmcp-cli获取选中视图截图", "通过lookinmcp-cli获取选中视图样式", or "排查lookinmcp-cli调用失败".
version: 0.1.0
---

# Lookin CLI Workflow

## Purpose
使用 `lookinmcp-cli` 完成三类任务：
- 获取选中视图信息与样式。
- 结合自然语言需求维护 Requirement / Code Info 映射。
- 获取选中视图截图。

## Trigger Scope
- 请求“CLI 获取选中视图属性/样式”时触发。
- 请求“CLI 结合自然语言需求找相关视图”时触发。
- 请求“CLI 获取选中节点截图”时触发。

## Workflow
1. 先执行 `lookinmcp-cli health`。  
2. 获取选中视图信息/样式时执行 `get_selected_view_context`。  
3. 获取截图时执行 `capture_selected_view_screenshot`。  
4. 处理自然语言需求时，先 `set_requirement_items --operation append` 写入需求，再 `get_requirement_code_info`读取映射。  
5. 映射不足时，要求用户在 Lookin 客户端手动把当前选中视图写入对应 Requirement 项。  

## CLI Installation (Required Before Use)
在执行命令前，先确保 `lookinmcp-cli` 可用。支持三种安装方式：

```bash
# 方式1：一次性执行（不安装）
npx --yes @cheng-pang/lookinmcp-cli health

# 方式2：全局安装（推荐高频使用）
npm install -g @cheng-pang/lookinmcp-cli
lookinmcp-cli --help

# 方式3：项目内安装（推荐团队仓库）
npm install -D @cheng-pang/lookinmcp-cli
./node_modules/.bin/lookinmcp-cli --help
```

### Sandbox / Network Note (Important)
- 在受限网络或沙箱环境中，`npx` / `npm` 可能因无法访问 npm registry 失败（常见为 `ENOTFOUND registry.npmjs.org`）。
- 这类场景下，优先申请提权后再执行 `npx` 命令。
- 若希望减少在线依赖，优先单独安装 CLI（全局或项目内）：

```bash
# 全局安装
npm install -g @cheng-pang/lookinmcp-cli
lookinmcp-cli health

# 或项目内安装
npm install -D @cheng-pang/lookinmcp-cli
./node_modules/.bin/lookinmcp-cli health
```

默认 MCP 地址为 `http://127.0.0.1:4010/mcp`。若端口不同，使用 `--url` 覆盖：

```bash
lookinmcp-cli --url http://127.0.0.1:4011/mcp health
```

## Manual Operations in Lookin Client (Required)
以下动作必须由用户手工执行：
- 启动 Lookin 客户端并连接目标 iOS App。
- 在 Hierarchy 树手动选中目标视图节点（上下文、样式、截图依赖该操作）。
- 在 Hierarchy/Preview 手动右键并执行 `add code info to item<id-description>`（自然语言映射依赖该操作）。

## Command Templates
```bash
# health
lookinmcp-cli health

# selected view info + style
lookinmcp-cli get_selected_view_context --children-depth 1

# append natural-language requirement
lookinmcp-cli set_requirement_items \
  --operation append \
  --items-json '[{"requirementId":"R-1","description":"点赞按钮","codeInfo":""}]'

# read requirement/code-info mapping
lookinmcp-cli get_requirement_code_info

# screenshot selected view
lookinmcp-cli capture_selected_view_screenshot --format png --output /tmp/lookin-selected.png
```

## Error Handling
- `LOOKINMCP_CLI_TRANSPORT_ERROR`：检查 Lookin MCP 地址与端口。  
- `LOOKINMCP_CLI_BAD_ARGUMENT`：修正子命令参数。  
- `status=no_session`：要求先在 Lookin 客户端建立会话。  
- `LOOKIN_MCP_NO_SELECTION`：要求先手动选中节点。  

## Additional Resources
- `references/manual-steps.md`
