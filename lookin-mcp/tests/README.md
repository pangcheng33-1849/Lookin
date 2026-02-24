# Lookin-MCP 测试说明

本目录提供 Lookin-MCP 的自动化与手动测试方法，面向日常开发回归。

## 目录结构

- `pytest.ini`：pytest marker 与扫描配置。
- `runner.py`：MCP Tool HTTP 调用封装。
- `conftest.py`：公共 fixture（会话、选中节点、场景开关）。
- `test_functional.py`：功能用例（F-001 ~ F-008）。
- `test_exceptions.py`：异常用例（E-001 ~ E-006）。
- `test_performance.py`：性能用例（P-001 ~ P-002）。
- `test_stability.py`：稳定性用例（S-001 ~ S-002）。

## 前置条件

1. 已启动 `LookinClient`，并连接到被检查 App（Lookin 内可看到 session）。
2. 需要执行选中节点相关用例时，先在 Lookin 左侧树中选中一个视图节点。
3. 设置 MCP 地址（默认端口 4010）：

```bash
export LOOKIN_MCP_TEST_BASE_URL="http://127.0.0.1:4010/mcp"
export LOOKIN_MCP_TEST_TIMEOUT_SEC=15
```

> 当前仅支持标准 MCP endpoint：`/mcp`。旧的 `/mcp/tool` 协议已移除。

## Coding Agent 测试方式（推荐）

适用于 Coding Agent/命令行自动回归。

```bash
cd Lookin
source .venv/bin/activate
python -m pytest lookin-mcp/tests -q
```

按类别执行：

```bash
python -m pytest lookin-mcp/tests -m functional -q
python -m pytest lookin-mcp/tests -m exception -q
python -m pytest lookin-mcp/tests -m performance -q
python -m pytest lookin-mcp/tests -m stability -q
```

按单个用例执行：

```bash
python -m pytest lookin-mcp/tests/test_functional.py -k F_004 -q
python -m pytest lookin-mcp/tests/test_exceptions.py -k E_003 -q
```

场景化异常用例（示例）：

```bash
LOOKIN_MCP_SCENARIO_NO_SESSION=1 python -m pytest lookin-mcp/tests/test_exceptions.py -k E_001 -q
LOOKIN_MCP_SCENARIO_NO_SELECTION=1 python -m pytest lookin-mcp/tests/test_exceptions.py -k E_002 -q
LOOKIN_MCP_SCENARIO_SCREENSHOT_FAIL=1 python -m pytest lookin-mcp/tests/test_exceptions.py -k E_006 -q
LOOKIN_MCP_SCENARIO_SESSION_SWITCH=1 python -m pytest lookin-mcp/tests/test_stability.py -k S_002 -q
```

## 提权执行规范（Coding Agent）

### 失败重试固定规则

1. 命令执行只要返回 `SandboxDenied`，立即使用“同一条命令 + `require_escalated`”重跑。
2. 不做分支动作，不改命令结构，不切换到其他等价命令。
3. 重跑后再判断业务结果（通过/失败/跳过）。

### 需要提权的命令清单

以下命令在 Coding Agent 沙箱环境中默认按“需要提权”处理：

```bash
# 协议与回归测试（会访问本地 MCP 端口）
Lookin/.venv/bin/python -m pytest Lookin/lookin-mcp/tests/test_protocol.py -q
Lookin/.venv/bin/python -m pytest Lookin/lookin-mcp/tests/test_functional.py -q
Lookin/.venv/bin/python -m pytest Lookin/lookin-mcp/tests/test_exceptions.py -q
Lookin/.venv/bin/python -m pytest Lookin/lookin-mcp/tests/test_stability.py -q
Lookin/.venv/bin/python -m pytest Lookin/lookin-mcp/tests/test_performance.py -q

# 构建/运行
xcodebuildmcp --style minimal macos build ...
xcodebuildmcp --style minimal macos build-and-run ...

# 手动协议调用（本地端口）
curl -sS -X POST "$LOOKIN_MCP_TEST_BASE_URL" ...
```

## 手动测试方式

适用于联调 UI 与工具行为（右键菜单、看板、截图文件）。

1. 启动并连接
- 打开 `LookinClient` 并连接目标 App。
- 在 Lookin 里选中任意视图节点。

2. 验证 Health

```bash
curl -sS -X POST "$LOOKIN_MCP_TEST_BASE_URL" \
  -H 'Content-Type: application/json' \
  -H 'MCP-Protocol-Version: 2025-06-18' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"lookin.health","arguments":{}}}'
```

3. 验证上下文与截图

```bash
curl -sS -X POST "$LOOKIN_MCP_TEST_BASE_URL" \
  -H 'Content-Type: application/json' \
  -H 'MCP-Protocol-Version: 2025-06-18' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"lookin.get_selected_view_context","arguments":{"childrenDepth":1}}}'

curl -sS -X POST "$LOOKIN_MCP_TEST_BASE_URL" \
  -H 'Content-Type: application/json' \
  -H 'MCP-Protocol-Version: 2025-06-18' \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"lookin.capture_selected_view_screenshot","arguments":{"format":"png"}}}'
```

4. 验证 Requirement/Code Info

```bash
curl -sS -X POST "$LOOKIN_MCP_TEST_BASE_URL" \
  -H 'Content-Type: application/json' \
  -H 'MCP-Protocol-Version: 2025-06-18' \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"lookin.set_requirement_items","arguments":{"operation":"append","items":[{"requirementId":"R-1","description":"点赞按钮","codeInfo":"初始值"}]}}}'

curl -sS -X POST "$LOOKIN_MCP_TEST_BASE_URL" \
  -H 'Content-Type: application/json' \
  -H 'MCP-Protocol-Version: 2025-06-18' \
  -d '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"lookin.get_requirement_code_info","arguments":{}}}'
```

5. UI 联动检查
- 在 Hierarchy/Preview 右键菜单执行 `Code Info` 写入动作。
- 打开 Requirement Code Info Board，确认 `codeInfo` 立即变化。
- 若截图返回 `path`，确认该文件存在且可打开。

## CLI 测试方式（lookinmcp-cli）

CLI 目录：`lookin-mcp/cli/`，默认通过 `http://127.0.0.1:4010/mcp` 调用 MCP。

```bash
node lookin-mcp/cli/bin/lookinmcp-cli.js --help
node lookin-mcp/cli/bin/lookinmcp-cli.js health
node lookin-mcp/cli/bin/lookinmcp-cli.js get_selected_view_context --children-depth 1
node lookin-mcp/cli/bin/lookinmcp-cli.js get_requirement_code_info
node lookin-mcp/cli/bin/lookinmcp-cli.js set_requirement_items --operation append --items-json '[{"requirementId":"R-1","description":"点赞按钮","codeInfo":"DUXDiggButton"}]'
node lookin-mcp/cli/bin/lookinmcp-cli.js capture_selected_view_screenshot --format png --output /tmp/lookin-selected.png
```

## 常见问题

- `status=no_session`：Lookin 尚未连接被检查 App。
- `LOOKIN_MCP_NO_SELECTION`：未选中节点，先在左侧树选择视图。
- `LOOKIN_MCP_TRANSPORT_ERROR`：检查 `LOOKIN_MCP_TEST_BASE_URL` 与服务进程状态。
