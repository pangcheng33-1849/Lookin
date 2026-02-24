# Lookin MCP 接入标准待办（todo2）

目标：将当前 Lookin MCP 从“自定义本地 HTTP Tool 服务”升级为“通用 Coding Agent 可直接接入的标准 MCP Server”。

## P0（阻断接入）

- [x] 实现 MCP 生命周期握手：`initialize` + `notifications/initialized`，完成版本协商与 capabilities 返回。
- [x] 实现标准工具方法：`tools/list` 与 `tools/call`，不再仅依赖 `POST /mcp/tool + {name,arguments}`。
- [x] 统一 JSON-RPC 2.0 包装：请求/响应包含 `jsonrpc` 与 `id` 关联。
- [x] 对齐 Streamable HTTP：统一 MCP endpoint，支持协议头（`MCP-Protocol-Version`），会话头（`Mcp-Session-Id`，若启用会话），并处理不支持方法（如 GET 返回 405）。
- [x] 对齐 `tools/call` 返回结构：支持标准 `content[]`，可附 `structuredContent`，错误语义支持 `isError`。

## P1（高优先级）

- [ ] 启用本地鉴权：落地启动 token 校验（当前逻辑为注释禁用状态）。
- [ ] 增加 Origin 校验与最小暴露策略（保持仅 `127.0.0.1`）。
- [ ] 梳理错误码语义：协议层错误使用 JSON-RPC 标准错误码；业务层错误进入 `tools/call` 结果或标准 error data。
- [ ] 增加官方 SDK/Inspector 互通测试：至少覆盖 `initialize -> tools/list -> tools/call`。

## P2（可后置）

- [ ] 增加 `ping` 与必要通知（如 `notifications/tools/list_changed`）。
- [ ] 如启用会话，补充会话终止路径（例如 DELETE 语义）。
- [ ] 评估并优化并发模型（当前工具执行串行主线程，长调用会阻塞后续请求）。

## 参考标准

- Lifecycle: <https://modelcontextprotocol.io/specification/2025-06-18/basic/lifecycle>
- Transports (Streamable HTTP): <https://modelcontextprotocol.io/specification/2025-06-18/basic/transports>
- Tools: <https://modelcontextprotocol.io/specification/2025-06-18/server/tools>
- Schema (`tools/list` / `tools/call` / `CallToolResult`): <https://modelcontextprotocol.io/specification/2025-11-25/schema>
- Base Message Model (JSON-RPC): <https://modelcontextprotocol.io/specification/2025-11-25/basic>
