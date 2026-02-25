---
name: lookin-mcp
description: This skill should be used when the user asks to "通过Lookin获取选中视图信息", "通过Lookin找到自然语言描述的相关视图", "通过Lookin获取选中视图截图", "通过Lookin获取选中视图样式", "通过node id获取视图信息或截图", "获取当前层级树", or "用MCP调用Lookin工具".
version: 0.2.0
---

# Lookin MCP Workflow

## Purpose
使用标准 MCP（JSON-RPC 2.0 + `/mcp`）完成以下任务：
- 获取选中视图信息与样式（Dashboard 属性）。
- 获取层级树（roots 或指定 nodeId 的子树）。
- 通过 nodeId 获取目标视图上下文。
- 将自然语言需求映射到相关视图（Requirement / Code Info）。
- 获取选中视图或指定 nodeId 视图截图。

## Trigger Scope
- 请求“获取当前选中视图的属性/样式/层级”时触发。
- 请求“获取当前全部 hierarchy / 某个 node 的层级子树”时触发。
- 请求“通过 node id 获取 view context / screenshot”时触发。
- 请求“根据自然语言需求找到相关视图”时触发。
- 请求“获取当前选中视图截图”时触发。

## Examples
### Example 0
User input:
`/lookin-mcp 设置点赞按钮、评论按钮的requirement，让用户在Lookin中关联选择对应视图的code info`

Agent workflow:
1. 调用 `lookin.health`。
2. 调用 `lookin.set_requirement_items`，以 `append` 一次写入两个 item（点赞、评论）。
3. 明确提示用户到 Lookin 客户端中对这两个 requirement 执行 `add code info to item<id-description>`。
4. 调用 `lookin.get_requirement_code_info`。
5. 若 `codeInfo` 仍为空，继续提示用户完成手工关联后重试第 4 步。

### Example 1
User input:
`/lookin-mcp 获取选中视图的信息`

Agent workflow:
1. 调用 `lookin.health`。
2. 调用 `lookin.get_selected_view_context`（推荐 `childrenDepth=1`）。
3. 从返回中的 `iosRaw`、`dashboard.groups`、`structureHints` 总结类型、层级关系和关键样式。

### Example 2
User input:
`/lookin-mcp 获取选中视图的截图`

Agent workflow:
1. 调用 `lookin.health`。
2. 调用 `lookin.capture_selected_view_screenshot`（`format=png`）。
3. 返回截图路径并说明对应 `nodeId`。

### Example 3
User input:
`/lookin-mcp 通过hierarchy 找到点赞按钮的相关类`

Agent workflow:
1. 调用 `lookin.health`。
2. 调用 `lookin.get_hierarchy_by_node_id`（`depth=6`）获取全局层级。
3. 在 `className/ivarNameOfParent` 中匹配关键词（如 `like`、`digg`、`点赞`）定位候选 `nodeId`。
4. 若某节点 `children=[]` 但 `hasChildren=true`，提高 `depth` 后重查，避免被深度限制误判为叶子节点。
5. 对候选节点调用 `lookin.get_view_context_by_node_id`（`childrenDepth=0`）确认类名链路。

### Example 4
User input:
`/lookin-mcp 获取点赞按钮的约束信息`

Agent workflow:
1. 若已知 `nodeId`，调用 `lookin.get_view_context_by_node_id`；否则先按 Example 3 定位节点。
2. 从返回的 `dashboard.groups` 中读取 `AutoLayout` 分组下的约束、优先级、intrinsic 信息。
3. 输出约束摘要并标出关键冲突风险（如优先级冲突、缺失约束）。

### Example 5
User input:
`/lookin-mcp 获取右侧交互区的视图结构`

Agent workflow:
1. 调用 `lookin.health`。
2. 先调用 `lookin.get_hierarchy_by_node_id`（`depth=6`）找到右侧交互区对应节点（常见关键词：`RightActions`、`交互`）。
3. 调用 `lookin.get_hierarchy_by_node_id`（`nodeId=<right-actions-node-id>`, `depth=3`）获取局部子树。
4. 对 `children=[]` 且 `hasChildren=true` 的节点继续提升 `depth` 递归展开。
5. 输出右侧交互区的结构化视图树（`className`、`ivarNameOfParent`、`hasChildren`、`nodeId`）。

## Workflow
1. 先调用 `lookin.health` 确认 Lookin session 可用。  
2. 获取选中视图信息/样式时，调用 `lookin.get_selected_view_context`。  
3. 获取层级树时，调用 `lookin.get_hierarchy_by_node_id`。`nodeId` 不传表示从 roots 开始；`depth` 取值范围 `[0, 16]`。  
4. 通过 nodeId 获取视图上下文时，调用 `lookin.get_view_context_by_node_id`（必须传 `nodeId`）。  
5. 获取选中视图截图时，调用 `lookin.capture_selected_view_screenshot`。  
6. 获取指定 nodeId 截图时，调用 `lookin.capture_view_screenshot_by_node_id`（必须传 `nodeId`）。  
7. 处理自然语言需求时，先调用 `lookin.set_requirement_items` 写入需求项，再调用 `lookin.get_requirement_code_info`读取映射结果。  
8. 映射不足时，提示用户在 Lookin 客户端通过右键菜单把当前选中视图写入对应 Requirement 的 Code Info。  

## Manual Operations in Lookin Client (Required)
以下动作必须由用户在 Lookin 客户端手工完成：
- 启动 Lookin 客户端并保持运行。
- 连接目标 iOS App，确保有可用 session。
- 在 Hierarchy 树手动选中目标视图节点（上下文/样式/截图依赖此步骤）。
- 在 Hierarchy 或 Preview 手动右键，执行 `add code info to item<id-description>`（自然语言映射依赖此步骤）。

补充说明：
- `get_view_context_by_node_id` / `capture_view_screenshot_by_node_id` 不依赖当前选中节点，但要求 `nodeId` 在当前会话中存在。

## Error Handling
- `LOOKIN_MCP_TRANSPORT_ERROR`：检查 Lookin 进程与 `4010` 端口。  
- `status=no_session`：先在 Lookin 客户端连接目标 App。  
- `LOOKIN_MCP_NO_SELECTION`：先在 Hierarchy 树手动选中节点。  
- `LOOKIN_MCP_NODE_NOT_FOUND`：`nodeId` 不存在，先通过 `lookin.get_hierarchy_by_node_id` 确认有效节点。  
- `LOOKIN_MCP_BAD_ARGUMENT`：参数不合法（例如 `depth > 16`）。  

## Additional Resources
- `references/manual-steps.md`
