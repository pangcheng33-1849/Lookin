---
name: lookin-mcp
description: This skill should be used when the user asks to "通过Lookin获取选中视图信息", "通过Lookin找到自然语言描述的相关视图", "通过Lookin获取选中视图截图", "通过Lookin获取选中视图样式", or "用MCP调用Lookin工具".
version: 0.1.0
---

# Lookin MCP Workflow

## Purpose
使用标准 MCP（JSON-RPC 2.0 + `/mcp`）完成三类任务：
- 获取选中视图信息与样式（Dashboard 属性）。
- 将自然语言需求映射到相关视图（Requirement / Code Info）。
- 获取选中视图截图。

## Trigger Scope
- 请求“获取当前选中视图的属性/样式/层级”时触发。
- 请求“根据自然语言需求找到相关视图”时触发。
- 请求“获取当前选中视图截图”时触发。

## Workflow
1. 先调用 `lookin.health` 确认 Lookin session 可用。  
2. 获取选中视图信息/样式时，调用 `lookin.get_selected_view_context`。  
3. 获取选中视图截图时，调用 `lookin.capture_selected_view_screenshot`。  
4. 处理自然语言需求时，先调用 `lookin.set_requirement_items` 写入需求项，再调用 `lookin.get_requirement_code_info`读取映射结果。  
5. 映射不足时，提示用户在 Lookin 客户端通过右键菜单把当前选中视图写入对应 Requirement 的 Code Info。  

## Manual Operations in Lookin Client (Required)
以下动作必须由用户在 Lookin 客户端手工完成：
- 启动 Lookin 客户端并保持运行。
- 连接目标 iOS App，确保有可用 session。
- 在 Hierarchy 树手动选中目标视图节点（上下文/样式/截图依赖此步骤）。
- 在 Hierarchy 或 Preview 手动右键，执行 `add code info to item<id-description>`（自然语言映射依赖此步骤）。

## Error Handling
- `LOOKIN_MCP_TRANSPORT_ERROR`：检查 Lookin 进程与 `4010` 端口。  
- `status=no_session`：先在 Lookin 客户端连接目标 App。  
- `LOOKIN_MCP_NO_SELECTION`：先在 Hierarchy 树手动选中节点。  

## Additional Resources
- `references/manual-steps.md`
