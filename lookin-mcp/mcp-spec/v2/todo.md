# Lookin-MCP v2 TODO

目标：新增 3 个能力

1. `lookin.get_hierarchy_by_node_id`
2. `lookin.get_view_context_by_node_id`
3. `lookin.capture_view_screenshot_by_node_id`

## 0. 对齐与冻结

- [x] 冻结 3 个 tool 名称与参数命名（避免实现后再重命名）。
- [x] 明确 `nodeId` 规则继续沿用 v1（优先 `viewOid`，否则 `layerOid`）。
- [x] 冻结 `get_hierarchy_by_node_id` 参数：`nodeId?`（可选）+ `depth`（默认值确定）。
- [x] 冻结 hierarchy 节点字段：仅 `nodeId/className/ivarNameOfParent/hasChildren`。
- [x] 冻结 context 返回命名：`get_view_context_by_node_id` 使用 `targetNode`。

## 1. 协议与文档

- [x] 新增 `API_SPEC.md`（v2）：补 3 个 tool 的 input/output schema 与示例。
- [x] 在 `TECHNICAL_DESIGN.md` 补齐最终字段裁剪策略（最小节点字段集）。
- [x] 更新错误码清单：新增 `LOOKIN_MCP_NODE_NOT_FOUND`。
- [x] 在 v2 API_SPEC 中明确：`targetNode` 内部 schema 复用 v1 的 `selectedNode` schema。

## 2. Router 与服务实现

- [x] `LKMCPToolRouter` 注册 3 个 tool 到 dispatch 与 `tools/list`。
- [ ] 参数校验：
  - [x] `nodeId` 可选；传入时必须非空字符串
  - [x] `depth >= 0`
  - [x] `childrenDepth >= 0`
- [x] `LKMCPContextService` 新增公开方法：
  - [x] `buildHierarchyPayloadByNodeId:arguments:error:`
  - [x] `buildViewContextPayloadByNodeId:arguments:error:`
  - [x] `captureScreenshotByNodeId:arguments:error:`
- [x] 先抽公共私有方法（item 维度核心实现）：
  - [x] `_buildContextPayloadForItem:childrenDepth:`
  - [x] `_captureScreenshotForItem:...`
- [x] 将 v1 selected 路径改为 wrapper（仅做 selected item 解析 + 调用公共私有方法）。
- [x] v2 by-node-id 路径复用同一公共私有方法（禁止复制上下文/截图主逻辑）。
- [x] 实现 `nodeId -> LookinDisplayItem` 定位（复用 `displayItemWithOid:`）。
- [x] 实现 hierarchy DFS 序列化 + `depth` 控制。
- [x] `nodeId` 为空时默认从 roots 开始。

## 3. CLI 支持

- [x] `lookin-mcp/cli/bin/lookinmcp-cli.js` 扩展 `COMMANDS`：
  - [x] `get_hierarchy_by_node_id`
  - [x] `get_view_context_by_node_id`
  - [x] `capture_view_screenshot_by_node_id`
- [x] 补 parser/buildArgs/help 文案。
- [x] `cli/README.md` 增加命令示例。

## 4. 测试补齐

- [x] `tests/test_protocol.py`：校验新 tool 出现在 `tools/list`。
- [ ] `tests/test_functional.py`：
  - [x] hierarchy 合同字段（仅 `nodeId/className/ivarNameOfParent/hasChildren`）与 `depth` 行为
  - [x] `nodeId` 为空默认 roots 起始
  - [x] nodeId 获取 context（命中路径）
  - [x] 同节点对比：selectedNode 与 targetNode 内容一致
  - [x] 同节点对比：selected screenshot 与 by-node-id screenshot 返回字段一致
  - [x] nodeId 截图落地与元数据校验
- [ ] `tests/test_exceptions.py`：
  - [x] 非法 `nodeId/depth/childrenDepth`
  - [x] 节点不存在返回 `LOOKIN_MCP_NODE_NOT_FOUND`
- [x] `tests/test_stability.py`：将 3 个新 tool 纳入循环调用。

## 5. 手工验证

- [ ] 在 Lookin 连接目标 App 且 hierarchy 可见时：
  - [ ] `get_hierarchy_by_node_id` 在 `nodeId` 为空时返回 roots 子树
  - [ ] `get_hierarchy_by_node_id` 在指定 `nodeId` 时返回该节点子树
  - [ ] 除 `children` 结构字段外，返回节点数据字段仅含 `nodeId/className/ivarNameOfParent/hasChildren`
  - [ ] 同一节点上，selectedNode 与 targetNode 内容一致，screenshot 返回字段一致
  - [ ] 随机抽 3 个 `nodeId` 调 `get_view_context_by_node_id` 成功
  - [ ] 用同一 `nodeId` 调 `capture_view_screenshot_by_node_id` 成功
- [ ] 校验不存在 `nodeId` 返回一致错误结构。

## 6. 验收标准（Done Definition）

- [ ] 3 个新 tool 通过自动化（functional/exceptions/protocol/stability）。
- [ ] 不回归 v1 既有 5 个 tool 行为和 schema。
- [ ] `targetNode` 内部结构与 v1 `selectedNode` 一致，screenshot 返回结构与 v1 保持一致。
- [ ] CLI 与文档示例均可直接执行。
- [ ] 代码与文档提交到 `mcp-spec/v2`，可支撑后续开发排期。
