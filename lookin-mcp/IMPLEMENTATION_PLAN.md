# Lookin-MCP 实现 TODO 清单（可勾选）

## 0. 执行约束

- [x] 仅实现 5 个 Tool：`health / get_selected_view_context / set_requirement_items / get_requirement_code_info / capture_selected_view_screenshot`。
- [x] `set_requirement_items` 仅支持 `operation=append/remove`。
- [x] `get_requirement_code_info` 仅返回 `requirementId/description/codeInfo`。
- [x] 新增文件尽量统一放在：`Lookin-Develop/LookinClient/MCP/LookinMCP/`。

## 1. 新增文件（统一目录）

- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKMCPServerRuntime.h`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKMCPServerRuntime.m`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKMCPToolRouter.h`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKMCPToolRouter.m`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKMCPError.h`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKMCPError.m`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKMCPContextService.h`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKMCPContextService.m`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKRequirementBindingService.h`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKRequirementBindingService.m`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKRequirementBindingStore.h`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKRequirementBindingStore.m`
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKMCPNotifications.h`

## 2. M1（health/context/screenshot）

- [x] 接入 `LKMCPServerRuntime`（本地回环 HTTP、启动/停止、会话 token）。
- [x] 完成 `LKMCPToolRouter` 的 Tool 分发与参数校验。
- [x] 实现 `lookin.health`（低复杂度，不遍历 hierarchy/attributes）。
- [x] 实现 `lookin.get_selected_view_context`（Dashboard-first，输出与 API_SPEC 一致）。
- [x] 实现 `lookin.capture_selected_view_screenshot`（写缓存路径，返回 `path/width/height/...`）。
- [x] 打通统一错误码：`NO_SESSION / NO_SELECTION / BAD_ARGUMENT / SCREENSHOT_FAILED`。
- [x] 手工冒烟：3 个 Tool 可连续调用且输出字段完整。

## 3. M2（Code Info 全链路）

- [x] 实现 `RequirementCodeInfoStore`（内存 + UserDefaults + TTL 档位）。
- [x] 实现 `set_requirement_items`（append/remove 主流程）。
- [x] `append` 校验 `requirementId + description`。
- [x] `remove` 校验 `requirementId` 存在性。
- [x] 同请求内重复 `requirementId` 返回 `DUP_REQUIREMENT_ID`。
- [x] 实现 `get_requirement_code_info`（仅返回 3 字段）。
- [x] 新增独立 `Code Info` 看板（字段：Requirement ID / Description / Code Info）。
- [x] 左侧 `LKHierarchyView.menuNeedsUpdate` 增加 `Code Info >`。
- [x] 中间 `LKPreviewController.menuNeedsUpdate` 增加 `Code Info >`。
- [x] 三处联动通知：`NotificationName_RequirementCodeInfoDidChange`。
- [ ] 联动 SLA：操作后 1s 内三处状态可见一致。
- [x] 工具栏 MCP 状态指示（服务状态/端口/会话状态）。

## 4. M3（收敛与验收，开发态非阻塞）

- [ ] `get_selected_view_context` 性能建议值 P95 <= 3s（开发态）。
- [ ] `get_requirement_code_info` 性能建议值 P95 <= 2s（开发态）。
- [ ] 连续调用建议值 30 次无崩溃、无不可恢复状态（开发态）。
- [ ] 错误码触发路径逐条验证并补齐边界用例。
- [ ] 文档一致性检查：`API_SPEC.md / UI_SPEC.md / PRD.md / TEST_PLAN.md`。

## 5. 现有文件改造点（本期实际）

- [x] `Lookin-Develop/LookinClient/Hierarchy/LKHierarchyView.m`（`menuNeedsUpdate` 菜单注入 + 打开看板入口）
- [x] `Lookin-Develop/LookinClient/Static/Preview/LKPreviewController.m`（`menuNeedsUpdate` 菜单注入 + 打开看板入口）
- [x] `Lookin-Develop/LookinClient/MCP/LookinMCP/LKRequirementBindingStore.m`（Code Info 看板 + 编辑即写入 + 通知）
- [x] `Lookin-Develop/LookinClient/Toolbar/LKWindowToolbarHelper.h`
- [x] `Lookin-Develop/LookinClient/Toolbar/LKWindowToolbarHelper.m`（新增 `MCP` 状态工具栏项）
- [x] `Lookin-Develop/LookinClient/Static/LKStaticWindowController.m`（状态项接线，实时显示服务/端口/会话）

## 6. 风险与回滚（执行时勾选）

- [ ] 菜单注入异常时可通过开关关闭新增菜单，仅保留 MCP 后端。
- [ ] Dashboard 卡片异常时可回退卡片注册，不影响既有属性卡片。
- [ ] 会话刷新造成脏数据时可一键清理 `mcp_requirement_code_info_*`。
- [ ] 持久化异常时可退回“仅会话内内存态”。
