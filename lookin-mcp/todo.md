# Lookin-MCP 文档 TODO

> 范围：仅保留 1 / 3 / 5 / 6（API 规格、UI 规格、测试计划、实现拆分）。

## [x] 1) `API_SPEC.md`
- 目标：定义所有 MCP Tool 的请求/响应契约，作为编码唯一接口依据。
- 需覆盖：
  - `lookin.health`
  - `lookin.get_selected_view_context`
  - `lookin.set_requirement_items`
  - `lookin.get_requirement_code_info`
  - `lookin.capture_selected_view_screenshot`
- 产出要求：
  - 每个 Tool：参数表 + JSON Schema + 成功示例 + 失败示例
  - 错误码全集：含语义、触发条件、恢复建议
  - 字段命名与语义保持简洁，不引入额外来源标签体系

## [x] 3) `UI_SPEC.md`
- 目标：把 FR-2 的交互细节固化为可实现稿，避免开发期解释偏差。
- 需覆盖：
  - `Code Info` 独立看板（字段、按钮、禁用态、文案）
  - 左侧 Hierarchy 右键菜单（打开看板/空态/列表只读）
  - 中间 3D/预览右键菜单（打开看板/空态/列表只读）
  - 三处联动刷新时序（操作后 1s 内可见）
- 产出要求：
  - 关键流程图（打开看板、编辑、刷新）
  - 状态矩阵（有数据/无数据/会话切换）
  - UI 文案清单（中英文策略若有）

## [x] 5) `TEST_PLAN.md`
- 目标：定义验收与回归测试边界，支撑 M1/M2/M3 交付。
- 需覆盖：
  - 功能测试：5 个 Tool 全链路
  - 异常测试：无会话、无选中、重复 requirementId、requirement 不存在、截图失败
  - 性能测试：`get_selected_view_context` P95、`get_requirement_code_info` P95
  - 稳定性测试：连续调用 100 次
- 产出要求：
  - 用例编号 + 前置条件 + 步骤 + 预期结果
  - 自动化与手工分层（哪些必须自动化）
  - 版本回归清单（发版前必跑）

## [x] 6) `IMPLEMENTATION_PLAN.md`
- 目标：把技术方案拆到“文件/类/任务”级，直接进入开发排期。
- 需覆盖：
  - M1：`health/context/screenshot`
  - M2：`code info` 全链路 + 工具栏状态（基础版）
  - M3：性能、错误码、文档收敛
- 产出要求：
  - 新增文件清单（类名、职责、依赖）
  - 现有文件改造点（函数级）
  - 风险项与回滚策略
  - 里程碑出口标准（DoD）

## 顺序建议
1. `API_SPEC.md`
2. `UI_SPEC.md`
3. `IMPLEMENTATION_PLAN.md`
4. `TEST_PLAN.md`
