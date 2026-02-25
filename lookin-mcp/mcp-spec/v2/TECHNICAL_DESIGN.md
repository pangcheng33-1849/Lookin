# Lookin-MCP 技术方案（V2）

版本：`v2`  
目标：在不破坏 v1 能力的前提下，新增 3 个 Tool：

1. 按 `nodeId` 获取 hierarchy 子树（`nodeId` 不传时从 roots 开始）。
2. 通过 `nodeId` 获取 view context。
3. 通过 `nodeId` 获取截图。

## 1. 背景与现状

当前 v1 只支持“当前选中节点”视角：

- `lookin.get_selected_view_context`
- `lookin.capture_selected_view_screenshot`

调研结论（代码基线）：

- Tool 路由与 schema 在 `LookinClient/MCP/LookinMCP/LKMCPToolRouter.m`。
- `nodeId` 已有统一规则（优先 `viewOid`，否则 `layerOid`），在 `LKMCPContextService` 内部已实现。
- 层级数据可通过 `LKHierarchyDataSource` 复用 `displayItemWithOid:` 做 `nodeId -> LookinDisplayItem` 映射。
- 完整树结构来自 `LookinHierarchyInfo.displayItems` + `LookinDisplayItem.subitems`。

## 2. 设计目标

- 与 v1 兼容：现有 5 个 Tool 不改名不改行为。
- 新增 3 个 Tool，统一 `lookin.*` 前缀。
- `nodeId` 解析规则与 v1 一致，避免双标准。
- 通过 `depth` 控制返回树深，避免 hierarchy 响应过大。
- `get_view_context_by_node_id` / `capture_view_screenshot_by_node_id` 必须复用原有 selected 逻辑，不允许复制两套业务实现。
- `get_view_context_by_node_id` / `capture_view_screenshot_by_node_id` 的返回内容与原有对应 tool 保持等价。

## 3. 新增 Tool 设计

## 3.1 `lookin.get_hierarchy_by_node_id`

用途：按起始节点返回 hierarchy 子树；`nodeId` 不传时从 roots 开始。

输入：

- `nodeId`：`string`（可选）
- `depth`：`integer`，最小 `0`，最大 `16`，默认 `1`

输出：

- `session`：`sessionId/appName/appBundleIdentifier/timestamp`
- `hierarchy`：
  - `startFrom`：`"roots"` 或 `"node"`
  - `startNodeId`：仅 `startFrom="node"` 时存在
  - `depth`
  - `nodes[]`（树结构）

`nodes[]` 每个节点数据字段仅包含：

- `nodeId`
- `className`（`LookinDisplayItem.title`）
- `ivarNameOfParent`（`LookinDisplayItem.subtitle`）
- `hasChildren`（`bool`，表示底层是否存在子节点）

树结构通过 `children[]` 组织。

深度语义：

- `depth=0`：仅返回起始层节点本身，不展开 children。
- `depth=1`：返回起始层节点及其一层 children，以此类推。
- 当 `children=[]` 时，可通过 `hasChildren` 区分：
  - `hasChildren=false`：确实没有子节点
  - `hasChildren=true`：有子节点但被 `depth` 限制未展开

## 3.2 `lookin.get_view_context_by_node_id`

用途：按 `nodeId` 获取目标节点上下文（内容结构与 `get_selected_view_context` 对齐）。

输入：

- `nodeId`：`string`（必填）
- `childrenDepth`：`integer`，最小 `0`，默认 `1`

输出：

- `session`
- `targetNode`

约束：`targetNode` 的内部结构与 v1 的 `selectedNode` 保持一致，仅节点键名不同。

错误语义：

- 节点不存在：`LOOKIN_MCP_NODE_NOT_FOUND`
- 节点不支持完整 dashboard 上下文（如 customInfo）：`LOOKIN_MCP_BAD_ARGUMENT`

## 3.3 `lookin.capture_view_screenshot_by_node_id`

用途：按 `nodeId` 导出目标节点截图。

输入：

- `nodeId`：`string`（必填）
- `format`：仅支持 `png`（默认 `png`）

输出：

- `path`
- `width` / `height`
- `timestamp`
- `sessionId`
- `nodeId`

约束：返回字段与 `lookin.capture_selected_view_screenshot` 保持一致。

错误语义：

- 节点不存在：`LOOKIN_MCP_NODE_NOT_FOUND`
- 截图失败：`LOOKIN_MCP_SCREENSHOT_FAILED`

## 4. 实现方案

## 4.1 路由层（`LKMCPToolRouter`）

- 在 tool 分发表新增 3 个分支。
- 在 `tools/list` 增加 3 个 tool 定义及 input schema。
- 新增参数校验：
  - `nodeId` 可选；传入时必须为非空字符串
  - `depth/childrenDepth` 边界检查

## 4.2 服务层（`LKMCPContextService`）

新增 3 个公开方法：

- `buildHierarchyPayloadByNodeId:arguments:error:`
- `buildViewContextPayloadByNodeId:arguments:error:`
- `captureScreenshotByNodeId:arguments:error:`

要求先做一层“按 item 处理”的抽象，然后 selected/by-node-id 双路径都走同一套核心实现：

- `_buildContextPayloadForItem:childrenDepth:`
- `_captureScreenshotForItem:format:`

v1 tool 的演进方式：

- `lookin.get_selected_view_context`：先解析 selected item，再调用 `_buildContextPayloadForItem:...`
- `lookin.capture_selected_view_screenshot`：先解析 selected item，再调用 `_captureScreenshotForItem:...`

v2 tool 的演进方式：

- `lookin.get_view_context_by_node_id`：先 `nodeId -> item`，再调用 `_buildContextPayloadForItem:...`
- `lookin.capture_view_screenshot_by_node_id`：先 `nodeId -> item`，再调用 `_captureScreenshotForItem:...`

约束：上下文字段映射、截图导出、错误包装逻辑应只保留一份核心实现，避免后续行为漂移。

## 4.3 `nodeId` 定位策略

1. 将 `nodeId` 解析为无符号 oid。
2. 先走 `LKStaticHierarchyDataSource.sharedInstance displayItemWithOid:oid`。
3. 找不到则返回 `LOOKIN_MCP_NODE_NOT_FOUND`。

说明：保持与 v1 `nodeId` 生成规则一致，不引入新 ID 体系。

## 4.4 hierarchy 子树序列化策略

- 若 `nodeId` 缺失：从当前会话 root items（`displayItems`）开始。
- 若 `nodeId` 存在：先定位目标节点，再从该节点开始。
- 节点输出按原 `subitems` 顺序，保证稳定性。
- 递归深度由 `depth` 控制；除 `children` 结构字段外，仅输出 `nodeId/className/ivarNameOfParent/hasChildren`。

## 4.5 兼容性与回归约束

- v1 现有 5 个 Tool 响应结构保持不变。
- 不修改 `lookin.get_selected_view_context` 与 `lookin.capture_selected_view_screenshot` 的对外契约。
- CLI 新增命令，不影响旧命令参数。
- selected 与 by-node-id 在命中同一节点时，应产出等价结果（context 仅 `selectedNode -> targetNode` 命名差异）。

## 5. 错误码扩展

新增：

- `LOOKIN_MCP_NODE_NOT_FOUND`

沿用：

- `LOOKIN_MCP_NO_SESSION`
- `LOOKIN_MCP_BAD_ARGUMENT`
- `LOOKIN_MCP_SCREENSHOT_FAILED`

## 6. 性能目标

- `lookin.get_hierarchy_by_node_id`：
  - `depth=2` 时，P95 `<= 2.5s`
- `lookin.get_view_context_by_node_id`：
  - P95 `<= 2s`
- `lookin.capture_view_screenshot_by_node_id`：
  - P95 `<= 2s`

## 7. 测试策略

- Functional：
  - hierarchy 合同字段校验（仅 `nodeId/className/ivarNameOfParent/hasChildren`）+ `depth` 行为
  - `nodeId` 缺失时 roots 起始行为
  - `nodeId` 命中/未命中路径
  - 同节点对比：`get_selected_view_context.selectedNode` 与 `get_view_context_by_node_id.targetNode` 内容一致
  - 同节点对比：`capture_selected_view_screenshot` 与 `capture_view_screenshot_by_node_id` 返回字段一致
  - 按 nodeId 截图文件落地校验
- Exceptions：
  - 非法 `nodeId/depth/childrenDepth`
  - 无会话与截图失败路径
- Stability：
  - 新增 3 个 tool 纳入循环 100 次稳定性测试

## 8. 里程碑

- M1：Router + ContextService 基础实现（3 tool 可跑通）
- M2：CLI + 自动化测试补齐
- M3：性能压测与错误信息收敛，文档更新
