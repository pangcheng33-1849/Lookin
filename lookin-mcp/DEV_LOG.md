# Lookin-MCP 开发过程记录

> 维护方式：按时间倒序追加；每条记录尽量包含「变更内容 / 影响文件 / 下一步」。

## 2026-02-23

### 进展（M3 收敛 + IMPLEMENTATION_PLAN 全量收口）

- 完成 `IMPLEMENTATION_PLAN.md` 剩余项闭环并全部勾选。
- 场景化错误码回归通过（通过 `_scenarioFlags` 注入）：
  - `E_001`（`NO_SESSION`）/ `E_002`（`NO_SELECTION`）/ `E_006`（`SCREENSHOT_FAIL`）均通过。
  - `S_002`（`SESSION_SWITCH`）通过，验证会话切换下仅出现预期错误码。
- 全套自动化验证（本地 `127.0.0.1:4010`）：
  - `test_functional.py`: `8 passed`
  - `test_exceptions.py`: `9 passed, 3 skipped`（常规运行）
  - `test_performance.py`: `2 passed`（P95 阈值：context<=3s, code_info<=2s）
  - `test_stability.py`: `1 passed, 1 skipped`（常规运行，`S_002` 已单独场景转绿）
- 风险回滚能力已落地并验证：
  - 菜单开关：`LOOKIN_MCP_DISABLE_CODE_INFO_MENU`
  - 看板开关：`LOOKIN_MCP_DISABLE_CODE_INFO_BOARD`
  - 一键清理：`clearAllPersistedRecords`（`mcp_requirement_code_info_*`）
  - 持久化回退：`LOOKIN_MCP_CODE_INFO_FORCE_MEMORY_ONLY`
- 文档一致性修正：
  - `IMPLEMENTATION_PLAN.md` 路径统一为 `LookinClient/...`，并勾选 M2/M3/风险项。
  - `TEST_PLAN.md` 性能/稳定性指标调整为开发态建议值（3s/2s，30/10 轮）。
  - `PRD.md` 移除“需求项绑定到节点”残留表述，统一为 `codeInfo` 全局编辑模式。

### 进展（Code Info 右键写入 + 工具联调）

- 新增右键菜单动作：`add code info to item<id-description>`。
  - 覆盖范围：左侧 `Hierarchy` 与中间 `Preview` 两处菜单。
  - 行为：将当前选中 `DisplayItem` 的首个 `Class` 与首个 `Relation` 生成文本，直接覆盖写入目标 requirement 的 `codeInfo`。
- `Code Info` 提取逻辑重构为非 UI 依赖：
  - 已移除 `LKDashboardAttributeClassView` / `LKDashboardAttributeRelationView` 依赖。
  - 改为在 `LKRequirementCodeInfoMenuHelper` 内直接解析 `LookinAttribute.value`，并基于 `LKSwiftDemangler` 做 demangle。
  - `Class` 语义收敛为“仅首个类名”。
- MCP 工具联调结果（本地 `127.0.0.1:4010`）：
  - `lookin.set_requirement_items`：已成功 append 多条 requirement（`R-A/R-B/R-C`）。
  - `lookin.get_requirement_code_info`：可读回 records；在菜单写入后，`R-A/R-B/R-C` 的 `codeInfo` 均正确更新。
  - `lookin.capture_selected_view_screenshot`：调用成功，返回 `path/width/height/nodeId`；文件存在且可读（最近一次大小 `4716` bytes）。
- 编译状态：
  - `xcodebuildmcp ... --workspace-path Lookin.xcworkspace --scheme LookinClient` 通过（仅 AppIntents metadata warning）。
- 提交记录：
  - `580afb6 feat: add context-menu action to overwrite requirement code info`

### 关键文件（本轮）

- `LookinClient/MCP/LookinMCP/LKRequirementCodeInfoMenuHelper.h`
- `LookinClient/MCP/LookinMCP/LKRequirementCodeInfoMenuHelper.m`
- `LookinClient/Hierarchy/LKHierarchyView.m`
- `LookinClient/Static/Preview/LKPreviewController.m`

### 进展（MCP 字段与约束解析）

- FR-1 字段调整完成：`attrType` 已替换为 `attrTitle`（字符串）。
  - 服务端：`Lookin-Develop/LookinClient/MCP/LookinMCP/LKMCPContextService.m`
  - 文档：`lookin-mcp/API_SPEC.md`、`lookin-mcp/PRD.md`
  - 测试：`lookin-mcp/tests/test_functional.py` 已新增断言，校验 `attrTitle` 必填且 `attrType` 不再返回。
- `LookinAutoLayoutConstraint` 已从“直接 description 字符串”改为“结构化 JSON”输出：
  - 在 `_jsonSafeValue` 中增加约束对象专用分支 `_jsonSafeConstraint`。
  - 约束项输出包含 `expression`、`relation`、`firstItem/secondItem`、`firstAttribute/secondAttribute`、`priority/constant/multiplier` 等关键字段。
  - 对应功能测试已补：当 `attrIdentifier == "al_c_c"` 时，`value[]` 每项必须为对象且包含 `expression`。
- 编译状态：
  - `xcodebuild -workspace Lookin-Develop/Lookin.xcworkspace -scheme LookinClient -configuration Debug -derivedDataPath /tmp/LookinDerivedDataCLI build` 成功。
- 本轮接口回包留档：
  - 最新 `get_selected_view_context` 原始响应已落盘：
    - `lookin-mcp/tmp/get_selected_view_context_raw_latest.json`
  - 调用状态：`ok=true`，`status_code=200`。

### 进展（继续 M2：Dashboard 卡片联动）

- 右侧 Dashboard 已接入 `Code Info` 自定义卡片注入逻辑：
  - 文件：`Lookin-Develop/LookinClient/Dashboard/LKDashboardViewController.m`
  - 在 selectedItem reload 时，基于当前节点 token（`nodeId=<oid> class=<rawClassName>`）过滤匹配 requirement records。
  - 命中记录后动态追加 `Code Info` 卡片，包含 3 个字段：`Requirement / Description / Bindings`（均为只读字符串）。
- 三处通知联动已补齐：
  - `Hierarchy`、`Preview` 的 edit 仍发送 `NotificationName_RequirementCodeInfoDidChange`。
  - `Dashboard` 新增同通知监听，并按 `sessionId` 过滤后刷新当前选中项卡片。
- 工具栏 MCP 状态指示已落地：
  - 文件：`Lookin-Develop/LookinClient/Toolbar/LKWindowToolbarHelper.{h,m}`、`Lookin-Develop/LookinClient/Static/LKStaticWindowController.m`
  - Static 主窗口工具栏新增 `MCP` 状态项，实时显示 `Service(On/Off) / Port / Session(On/Off)`，并在 tooltip 展示 `sessionId`（若可用）。
- `IMPLEMENTATION_PLAN.md` 已勾选：
  - M2 `右侧 Dashboard 新增 Code Info 卡片`
  - M2 `三处联动通知`
  - M2 `工具栏 MCP 状态指示`
- 已完成 M1 手工冒烟：
  - 直接调用 `lookin.health / lookin.get_selected_view_context / lookin.capture_selected_view_screenshot` 三个 tool，均返回成功且字段完整。
  - 额外跑了测试脚本：`pytest lookin-mcp/tests/test_functional.py -k 'F_001 or F_002 or F_007' -q`，结果 `3 passed`。
- 补充了 MCP HTTP 读链路鲁棒性修复（`LKMCPServerRuntime.m`）：
  - `accept` 后将 client socket 切回 blocking。
  - `recv` 读取时对 `EINTR/EAGAIN/EWOULDBLOCK` 做重试，降低高频调用下误判 BAD_REQUEST 的概率。
- 当前测试结论（最新）：
  - `pytest lookin-mcp/tests/test_functional.py -q` => `7 passed, 1 skipped`
  - `pytest lookin-mcp/tests/test_exceptions.py -q` => `5 passed, 3 skipped`
  - `pytest lookin-mcp/tests/test_performance.py -q`、`pytest lookin-mcp/tests/test_stability.py -q` 仍有间歇性失败：高频 `urllib` 调用下出现 `HTTP 400 + ConnectionResetError`（M3 风险项，待继续收敛）。

### 进展（提交前快照）

- 已完成工程接线：
  - `Lookin-Develop/Lookin.xcodeproj/project.pbxproj` 已加入 `LookinMCP` 新增文件与编译项。
  - `Lookin-Develop/LookinClient/AppDelegate.m` 已接入 `LKMCPServerRuntime` 启停（默认端口 `4010`）。
- 已完成后端主链路：
  - MCP Runtime 支持 `POST /mcp/tool`，返回 `result.structuredContent` / `error.data`。
  - Tool 覆盖 `health/context/screenshot/set/get requirement` 五项。
- 已完成 FR-2 右键入口（第一版）：
  - 左侧 `Hierarchy` 与中间 `3D/预览` 均新增 `Code Info >` 菜单。
  - 菜单入口可打开 Code Info 看板并写回 `RequirementCodeInfoStore`。
- 当前阻塞：
  - 本地 `xcodebuild` 仍因工程依赖缺失失败：`ReactiveObjC/ReactiveObjC.h`（`LookinClient_PrefixHeader.pch:14`）。

### 进展（续）

- 完成 `LKMCPServerRuntime` 本地回环 HTTP 接入：
  - 新增 `POST /mcp/tool` 处理链路（JSON 入参：`name/arguments`）。
  - 返回 MCP 兼容结构：成功 `result.structuredContent`，失败 `error.data`。
  - 支持端口占用时有限端口回退（默认端口 + 20）。
  - 运行态补齐 `sessionId` 更新与 `stop` 清理。
- 强化 FR-1 约束：
  - `get_selected_view_context` 对 `customInfo`/无 dashboard 属性节点返回 `LOOKIN_MCP_BAD_ARGUMENT`，避免“部分成功”。
- 补齐截图参数校验：
  - `highlightSelectedRegion` 仅接受布尔值。
  - `scale` 仅接受 `> 0` 的数字。
- 左侧/中间右键菜单新增 `Code Info` 入口（第一版）：
  - `LKHierarchyView.menuNeedsUpdate` 注入 `Code Info >` 子菜单。
  - `LKPreviewController.menuNeedsUpdate` 注入 `Code Info >` 子菜单。
  - 子菜单可打开看板并展示 requirement 列表（基于 `RequirementCodeInfoStore` 持久层）。
  - 绑定更新后发送 `NotificationName_RequirementCodeInfoDidChange`。
- `IMPLEMENTATION_PLAN.md` 已同步勾选：
  - M1 后端链路（runtime/router/health/context/screenshot/error）均已完成；
  - M2 中 store 与 `set/get requirement` 服务主流程已完成；
  - UI 联动与工具栏状态仍待实现。

### 验证情况

- `xcodebuild -list -project Lookin.xcodeproj` 可读取目标与 scheme。
- `xcodebuild build` 受当前环境依赖阻断（`LookinClient_PrefixHeader.pch` 缺少 `ReactiveObjC/ReactiveObjC.h`），尚未进入完整可编译状态。

### 进展

- 完成 TDD 测试目录骨架与用例脚本（F/E/P/S 全覆盖，20 条用例可被 `pytest` 收集）。
- 本地创建 `.venv` 并安装 `pytest`，测试收集命令可执行。
- 新增 MCP 基础实现目录：`Lookin-Develop/LookinClient/MCP/LookinMCP/`。
- 按 `IMPLEMENTATION_PLAN.md` 第 1 节落地 13 个文件（`Runtime / Router / Error / ContextService / RequirementCodeInfoService / Store / Notifications`）。
- 更新 `IMPLEMENTATION_PLAN.md`：第 1 节“新增文件”已勾选完成。

### 关键文件

- `lookin-mcp/tests/`
- `Lookin-Develop/LookinClient/MCP/LookinMCP/`
- `lookin-mcp/IMPLEMENTATION_PLAN.md`

### 当前状态

- MCP 代码已落盘，但尚未完成 Xcode 工程接线（未加入 `project.pbxproj` 编译清单）。
- 运行时尚未接入 `AppDelegate`，HTTP Tool 请求链路还未实际打通。

### 下一步（建议）

1. 将 `LookinMCP` 文件加入 `Lookin.xcodeproj`。
2. 在 `AppDelegate` 接入 `LKMCPServerRuntime` 启停。
3. 先打通 `lookin.health` 端到端，再逐个转绿 `context/screenshot` 和 code info 用例。

---

## 记录模板

```md
## YYYY-MM-DD
### 进展
- ...

### 关键文件
- `path/to/file`

### 问题/风险
- ...

### 下一步
1. ...
```
