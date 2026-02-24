# lookinmcp-cli TODO

目标：提供一个无需直接使用 MCP 的本地命令行工具 `lookinmcp-cli`，内部调用 Lookin MCP（`/mcp`），并保持命令语义与 MCP tools 尽量一致。

## 0. 命名与范围

- [x] CLI 可执行文件名固定为：`lookinmcp-cli`
- [x] 默认 MCP 地址：`http://127.0.0.1:4010/mcp`
- [x] 支持全局参数：`--url`、`--timeout`

## 1. 命令集（去前缀，语义与 MCP tool 对齐）

- [x] 实现命令：`lookinmcp-cli health`
- [x] 实现命令：`lookinmcp-cli get_selected_view_context`
- [x] 实现命令：`lookinmcp-cli set_requirement_items`
- [x] 实现命令：`lookinmcp-cli get_requirement_code_info`
- [x] 实现命令：`lookinmcp-cli capture_selected_view_screenshot`

说明：
- 命令名去掉 `lookin.` 前缀，保留 `snake_case`。
- 子命令与 MCP tool 的映射关系固定：
  - `health` -> `lookin.health`
  - `get_selected_view_context` -> `lookin.get_selected_view_context`
  - `set_requirement_items` -> `lookin.set_requirement_items`
  - `get_requirement_code_info` -> `lookin.get_requirement_code_info`
  - `capture_selected_view_screenshot` -> `lookin.capture_selected_view_screenshot`
- 参数名尽量与 API_SPEC 保持一致（如 `childrenDepth`、`operation`、`items`、`format`）。

## 2. Help 体系（必须项）

- [x] 根命令支持：`lookinmcp-cli --help` 与 `lookinmcp-cli -h`
- [x] 每个子命令支持：`lookinmcp-cli <subcommand> --help` 与 `-h`
- [x] Help 内容包含：
  - [x] 用途说明（对应哪个 MCP tool）
  - [x] 参数说明（类型、是否必填、默认值）
  - [x] 示例命令（最少 1 条）
  - [x] 失败返回说明（常见错误码/排查建议）

## 3. 参数与输入格式

- [x] `get_selected_view_context`：支持 `--children-depth <int>`
- [x] `set_requirement_items`：
  - [x] 支持 `--operation append|remove`
  - [x] 支持 `--items-json '<json>'`
- [x] `capture_selected_view_screenshot`：
  - [x] 支持 `--format png`
  - [x] 支持 `--output <path>`（若传入则将返回图片落盘到指定路径，行为写入 help）

## 4. 输出与错误处理

- [x] 成功输出默认返回 JSON（结构稳定，便于 Skill/Agent 解析）
- [x] 输出结构尽量贴近 MCP `tools/call` 的 `structuredContent`
- [x] 网络/协议失败统一错误前缀：`LOOKINMCP_CLI_*`
- [x] 保留服务端业务错误原文（`code/message/hint`）

## 5. 验收清单

- [x] `lookinmcp-cli --help` 可展示全部子命令
- [x] 任一子命令 `-h` 可显示参数与示例
- [x] 5 个命令均可通路到 Lookin MCP 并返回结果
- [x] 对无会话/无选中节点场景有明确错误提示
- [x] 文档补充到 `lookin-mcp/tests/README.md`（CLI 使用与样例）

## 6. 示例（验收时使用）

```bash
lookinmcp-cli health
lookinmcp-cli get_selected_view_context --children-depth 1
lookinmcp-cli get_requirement_code_info
lookinmcp-cli capture_selected_view_screenshot --format png
lookinmcp-cli set_requirement_items --operation append --items-json '[{"requirementId":"R-1","description":"点赞按钮","codeInfo":"DUXDiggButton"}]'
```
