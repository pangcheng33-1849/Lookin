# Lookin-MCP UI 规格（Code Info）

版本：`v2`  
范围：FR-2（Code Info），不新增 MCP Tool。

## 1. 目标

- 将原“节点绑定”交互改为“需求项对应代码信息”的全局编辑模式。
- `codeInfo` 仅表示自然语言需求对应的相关代码信息，不要求与当前节点建立真实绑定关系。

## 2. 信息结构

- 对外字段固定：`requirementId / description / codeInfo`。
- `codeInfo` 类型为 `String`，格式不限制。

## 3. 界面改动

- 右侧维持现有 Dashboard，不再承担节点绑定操作。
- 新增独立窗口：`Code Info Items`（全局看板）。
- 左侧 Hierarchy 右键菜单新增：`Code Info >`。
- 中间 3D/预览右键菜单新增：`Code Info >`。

## 4. 右键菜单行为

- 一级：`Code Info >`
- 二级：
  - `Open Code Info Board…`
  - requirement 列表（仅展示 `requirementId - description`，只读）
- 当 requirement 为空时，显示禁用提示：`No requirement items. Call set_requirement_items first.`

说明：菜单不再提供“关联到当前节点”类动作。

## 5. Code Info 看板字段

- `Requirement ID`：只读。
- `Description`：可编辑，修改后立即生效。
- `Code Info`：多行文本，可编辑，修改后立即生效。

操作：

- `Add`：新增 requirement 行（自动生成默认 `requirementId`）。
- `Delete`：删除当前行。
- `Reload`：从 store 重新加载。

说明：不提供 `Apply` / `Save All`，编辑即写入。

## 6. 一致性与刷新

- 看板编辑成功后发送 `NotificationName_RequirementCodeInfoDidChange`。
- 左右键菜单与看板在 `1s` 内完成可见状态同步。

## 7. 最小验收

- 三处入口（看板、左菜单、中菜单）均可稳定查看/编辑同一份 `codeInfo` 数据。
- 删除“节点绑定”相关逻辑后，`get_requirement_code_info` 返回数据仍正确。
- 右键菜单不再出现历史“节点绑定”动作文案。
