# Lookin-MCP UI 规格（精简版）

版本：`v1`  
范围：仅 FR-2（Requirement Binding）UI，不新增 MCP Tool。

## 1. 目标

- 在不改变 Lookin 三栏布局的前提下，提供“需求项与节点绑定”的最小可用交互。
- 避免新增复杂状态实体；对外读取仍以 `requirementId/description/bindings` 为准。

## 2. 必做改动

- 右侧 Dashboard 新增卡片：`Requirement Binding`（与现有卡片同级）。
- 左侧 Hierarchy 右键菜单新增：`Requirement Binding >`。
- 中间 3D/预览右键菜单新增：`Requirement Binding >`。

## 3. 右侧卡片（最小字段）

- `Requirement`：下拉，数据来自 requirement 列表。
- `Description`：只读，随选中 requirement 变化。
- `Bindings`：多行文本，`String`，格式不限制。

操作按钮：

- `绑定到当前节点`
- `解绑当前节点`
- `添加自定义 item`

禁用规则：

- 无 requirement：不可绑定，提示“请先添加 requirement”。
- 无选中节点：绑定/解绑不可用，提示“请先选择节点”。

## 4. 右键菜单行为

- 一级：`Requirement Binding >`
- 二级：
  - requirement 列表（点击即绑定当前右键节点）
  - 已绑定项显示 `Unbind from <requirementId-description>`
- requirement 为空时：一级菜单置灰。

## 5. 联动规则

- 任一入口执行绑定/解绑后，右侧卡片、左侧菜单、中间菜单在 `1s` 内同步刷新。
- 节点失效由服务端读取前清理；UI 不引入“失效状态字段”。

## 6. 文案（中文）

- `Requirement Binding >`
- `Unbind from <requirementId-description>`
- `请先添加 requirement`
- `请先选择节点`
- `绑定已更新`
- `解绑已更新`

## 7. 最小验收

- 三处入口都可完成绑定/解绑。
- 禁用态与提示文案正确。
- 操作后 1s 内三处状态一致。
- `get_requirement_bindings` 返回仅包含 `requirementId/description/bindings`。
