# Lookin-MCP 测试计划（V1）

## 1. 目标与范围

- 目标：为 M1/M2/M3 提供可执行的验收与回归测试基线。
- 范围：5 个 Tool 全链路。
  - `lookin.health`
  - `lookin.get_selected_view_context`
  - `lookin.set_requirement_items`（`append/remove`）
  - `lookin.get_requirement_bindings`
  - `lookin.capture_selected_view_screenshot`

## 2. 测试环境

- 客户端：Lookin macOS 客户端（含 MCP 功能分支）。
- 被测端：UIKit 应用（至少 1 个简单页面 + 1 个复杂页面）。
- 会话形态：有会话 / 无会话 / 会话刷新后节点变化。
- 数据准备：至少 10 条 requirement，覆盖绑定/解绑/删除。

## 3. 用例模板

- 用例编号
- 前置条件
- 步骤
- 预期结果
- 类型（自动化/手工）

## 4. 功能测试用例（主链路）

| 用例ID | 前置条件 | 步骤 | 预期结果 | 类型 |
| --- | --- | --- | --- | --- |
| F-001 | Lookin 已连接 App | 调用 `lookin.health` | 返回 `status=ok`，包含 `timestamp`；有会话时含 `sessionId` | 自动化 |
| F-002 | 当前已选中一个 UIKit 视图 | 调用 `lookin.get_selected_view_context` | 返回 `session + selectedNode`；`dashboard.groups[].sections[].attributes[]` 存在；无 `quality` 字段 | 自动化 |
| F-003 | 同 F-002 | `childrenDepth=0/1` 分别调用 | 结构提示字段随深度变化；主属性字段稳定 | 自动化 |
| F-004 | requirement 列表为空 | 调用 `set_requirement_items(operation=append)` 增加 2 条 | 返回 `operation=append`，`total` 正确 | 自动化 |
| F-005 | 已有 2 条 requirement | 调用 `set_requirement_items(operation=remove)` 删除 1 条 | 返回 `operation=remove`，`total` 减少，目标被删除 | 自动化 |
| F-006 | 已完成绑定操作 | 调用 `get_requirement_bindings` | `records[]` 仅含 `requirementId/description/bindings` 三字段 | 自动化 |
| F-007 | 已选中视图 | 调用 `capture_selected_view_screenshot` | 返回本地 `path`，文件存在且可打开，宽高>0 | 自动化 |
| F-008 | 右侧卡片/左右键菜单可用 | 在任一入口执行绑定/解绑 | 三处入口 1s 内状态一致 | 手工 |

## 5. 异常测试用例

| 用例ID | 场景 | 步骤 | 预期错误码 | 类型 |
| --- | --- | --- | --- | --- |
| E-001 | 无会话 | 调用 `health/context/bindings/screenshot` | `LOOKIN_MCP_NO_SESSION`（health 允许 `no_session` 成功态） | 自动化 |
| E-002 | 无选中节点 | 调用 `get_selected_view_context` 或 `capture_selected_view_screenshot` | `LOOKIN_MCP_NO_SELECTION` | 自动化 |
| E-003 | append 请求内重复 requirementId | 调用 `set_requirement_items(operation=append)` | `LOOKIN_MCP_DUP_REQUIREMENT_ID` | 自动化 |
| E-004 | remove 不存在 requirementId | 调用 `set_requirement_items(operation=remove)` | `LOOKIN_MCP_REQUIREMENT_NOT_FOUND` | 自动化 |
| E-005 | 非法参数（类型/取值越界） | 传非法 `childrenDepth` 等 | `LOOKIN_MCP_BAD_ARGUMENT` | 自动化 |
| E-006 | 截图写盘异常 | 模拟不可写路径或截图对象缺失 | `LOOKIN_MCP_SCREENSHOT_FAILED` | 自动化 |

## 6. 性能测试

| 指标ID | 接口 | 方法 | 通过标准 |
| --- | --- | --- | --- |
| P-001 | `get_selected_view_context` | 热身 10 次后连续 50 次，统计 P95 | P95 `<= 2s` |
| P-002 | `get_requirement_bindings` | 构造 100 条 requirement，连续 100 次读取 | P95 `<= 1s` |

说明：性能测试固定在“有会话+稳定页面”执行，避免外部波动干扰。

## 7. 稳定性测试

- S-001：混合调用 100 次（`health/context/set/get/screenshot`），无崩溃、无不可恢复状态。
- S-002：会话切换后重复执行 20 次主链路，错误码与恢复路径稳定。

## 8. 自动化与手工分层

- 必须自动化：
  - 全部 Tool 契约字段校验
  - 错误码触发校验
  - 性能基线采集
  - 100 次稳定性脚本
- 必须手工：
  - 右侧卡片、左/中右键菜单联动与交互体验
  - 禁用态与提示文案
  - 截图可视正确性（非空白、非错位）

## 9. 发版前回归清单

- [ ] 5 个 Tool 冒烟全部通过。
- [ ] 异常用例 E-001 ~ E-006 全部通过。
- [ ] 性能指标 P-001/P-002 达标。
- [ ] 稳定性 S-001 达标（100 次）。
- [ ] UI 联动手工回归通过（1s 同步）。
- [ ] 文档与实现一致性复核（API/UI/Implementation/Test）。
