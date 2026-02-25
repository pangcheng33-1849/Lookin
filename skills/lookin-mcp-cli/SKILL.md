---
name: lookin-mcp-cli
description: This skill should be used when the user asks to "通过lookinmcp-cli获取选中视图信息", "通过lookinmcp-cli找到自然语言描述的相关视图", "通过lookinmcp-cli获取选中视图截图", "通过lookinmcp-cli获取选中视图样式", "通过node id获取视图信息或截图", "获取层级树", or "排查lookinmcp-cli调用失败".
version: 0.2.0
---

# Lookin CLI Workflow

## Purpose
使用 `lookinmcp-cli` 完成以下任务：
- 获取选中视图信息与样式。
- 获取层级树（roots 或指定 nodeId 子树）。
- 通过 nodeId 获取目标视图上下文。
- 结合自然语言需求维护 Requirement / Code Info 映射。
- 获取选中视图或指定 nodeId 视图截图。

## Trigger Scope
- 请求“CLI 获取选中视图属性/样式”时触发。
- 请求“CLI 获取 hierarchy / 指定 node 子树”时触发。
- 请求“CLI 通过 node id 获取 view context / screenshot”时触发。
- 请求“CLI 结合自然语言需求找相关视图”时触发。
- 请求“CLI 获取选中节点截图”时触发。

## Examples
### Example 0
User input:
`/lookin-mcp-cli 设置点赞按钮、评论按钮的requirement，让用户在Lookin中关联选择对应视图的code info`

Agent workflow:
1. 执行 `lookinmcp-cli health`。
2. 执行 `lookinmcp-cli set_requirement_items --operation append --items-json '[{"requirementId":"R-LIKE","description":"点赞按钮","codeInfo":""},{"requirementId":"R-COMMENT","description":"评论按钮","codeInfo":""}]'`。
3. 明确提示用户到 Lookin 客户端中对这两个 requirement 执行 `add code info to item<id-description>`。
4. 执行 `lookinmcp-cli get_requirement_code_info`。
5. 若 `codeInfo` 仍为空，继续提示用户完成手工关联后重试第 4 步。

### Example 1
User input:
`/lookin-mcp-cli 获取选中视图的信息`

Agent workflow:
1. 执行 `lookinmcp-cli health`。
2. 执行 `lookinmcp-cli get_selected_view_context --children-depth 1`。
3. 从返回中的 `iosRaw`、`dashboard.groups`、`structureHints` 总结类型、层级关系和关键样式。

### Example 2
User input:
`/lookin-mcp-cli 获取选中视图的截图`

Agent workflow:
1. 执行 `lookinmcp-cli health`。
2. 执行 `lookinmcp-cli capture_selected_view_screenshot --format png --output /tmp/lookin-selected.png`。
3. 返回截图路径并说明对应 `nodeId`。

### Example 3
User input:
`/lookin-mcp-cli 通过hierarchy 找到点赞按钮的相关类`

Agent workflow:
1. 执行 `lookinmcp-cli health`。
2. 执行 `lookinmcp-cli get_hierarchy_by_node_id --depth 6` 获取全局层级。
3. 在 `className/ivarNameOfParent` 中匹配关键词（如 `like`、`digg`、`点赞`）定位候选 `nodeId`。
4. 若某节点 `children=[]` 但 `hasChildren=true`，提升 `--depth` 后重查，避免被深度限制误判为叶子节点。
5. 对候选节点执行 `lookinmcp-cli get_view_context_by_node_id --node-id <id> --children-depth 0`，确认类名链路。

### Example 4
User input:
`/lookin-mcp-cli 获取点赞按钮的约束信息`

Agent workflow:
1. 若已知 `nodeId`，执行 `lookinmcp-cli get_view_context_by_node_id --node-id <id> --children-depth 0`；否则先按 Example 3 定位节点。
2. 从返回的 `dashboard.groups` 中读取 `AutoLayout` 分组下的约束、优先级、intrinsic 信息。
3. 输出约束摘要并标出关键冲突风险（如优先级冲突、缺失约束）。

### Example 5
User input:
`/lookin-mcp-cli 获取右侧交互区的视图结构`

Agent workflow:
1. 执行 `lookinmcp-cli health`。
2. 先执行 `lookinmcp-cli get_hierarchy_by_node_id --depth 6` 找到右侧交互区对应节点（常见关键词：`RightActions`、`交互`）。
3. 执行 `lookinmcp-cli get_hierarchy_by_node_id --node-id <right-actions-node-id> --depth 3` 获取局部子树。
4. 对 `children=[]` 且 `hasChildren=true` 的节点继续提升 `depth` 递归展开。
5. 输出右侧交互区的结构化视图树（`className`、`ivarNameOfParent`、`hasChildren`、`nodeId`）。

## Workflow
1. 先执行 `lookinmcp-cli health`。  
2. 获取选中视图信息/样式时执行 `get_selected_view_context`。  
3. 获取层级树时执行 `get_hierarchy_by_node_id`。`--node-id` 可选；不传从 roots 开始。`--depth` 范围 `[0, 16]`。  
4. 通过 nodeId 获取上下文时执行 `get_view_context_by_node_id --node-id <id>`。  
5. 获取选中截图时执行 `capture_selected_view_screenshot`。  
6. 获取指定 nodeId 截图时执行 `capture_view_screenshot_by_node_id --node-id <id>`。  
7. 处理自然语言需求时，先 `set_requirement_items --operation append` 写入需求，再 `get_requirement_code_info`读取映射。  
8. 映射不足时，要求用户在 Lookin 客户端手动把当前选中视图写入对应 Requirement 项。  

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

# hierarchy from roots
lookinmcp-cli get_hierarchy_by_node_id --depth 1

# hierarchy from target node
lookinmcp-cli get_hierarchy_by_node_id --node-id 18 --depth 2

# view context by node id
lookinmcp-cli get_view_context_by_node_id --node-id 18 --children-depth 1

# append natural-language requirement
lookinmcp-cli set_requirement_items \
  --operation append \
  --items-json '[{"requirementId":"R-1","description":"点赞按钮","codeInfo":""}]'

# read requirement/code-info mapping
lookinmcp-cli get_requirement_code_info

# screenshot selected view
lookinmcp-cli capture_selected_view_screenshot --format png --output /tmp/lookin-selected.png

# screenshot by node id
lookinmcp-cli capture_view_screenshot_by_node_id --node-id 18 --format png --output /tmp/lookin-node.png
```

## Error Handling
- `LOOKINMCP_CLI_TRANSPORT_ERROR`：检查 Lookin MCP 地址与端口。  
- `LOOKINMCP_CLI_BAD_ARGUMENT`：修正子命令参数。  
- `status=no_session`：要求先在 Lookin 客户端建立会话。  
- `LOOKIN_MCP_NO_SELECTION`：要求先手动选中节点。  
- `LOOKIN_MCP_NODE_NOT_FOUND`：`nodeId` 不存在，先用 `get_hierarchy_by_node_id` 确认可用节点。  
- `LOOKIN_MCP_BAD_ARGUMENT`：参数不合法（例如 `--depth` 超过 16）。  

## Additional Resources
- `references/manual-steps.md`
