# Manual Steps Checklist (Lookin Client)

本清单覆盖“选中视图信息/样式、自然语言相关视图、选中视图截图”三类任务中的人工步骤。

## A. 选中视图信息 / 样式（人工前置）
- 打开 Lookin 客户端并连接目标 iOS App。
- 在 Hierarchy 树点选目标节点。
- 确认右侧 Dashboard 已切换到对应节点（Class / Relation / Layout / AutoLayout 等）。

## B. 自然语言找相关视图（人工映射）
- 在 Requirement 列表中先创建需求项（可由 API 写入）。
- 在 Hierarchy 或 Preview 选中疑似相关节点。
- 右键执行 `add code info to item<id-description>`，把当前节点的关键信息写入目标需求项。
- 重复对多个候选节点执行写入，直到映射足够清晰。

## C. 选中视图截图（人工前置）
- 在 Hierarchy 树再次确认目标节点为当前选中状态。
- 如需特定视觉状态（展开/收起、动画前后），先在被测 App 中手工切换到目标状态，再截图。

## Quick Verification
- `lookin.health` 返回 `status=ok`。
- `lookin.get_selected_view_context` 返回 dashboardSections 且不为空。
- `lookin.get_requirement_code_info` 返回目标 requirementId 的 codeInfo 变更。
- `lookin.capture_selected_view_screenshot` 返回 path 且文件存在。
