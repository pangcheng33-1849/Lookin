# Lookin-MCP TDD 测试目录

本目录提供按用例编号拆分的测试脚本，用于 TDD 驱动开发。

## 目录结构

- `pytest.ini`：pytest marker 注册与默认扫描配置。
- `runner.py`：统一调用 MCP Tool 的客户端封装（HTTP）。
- `conftest.py`：公共 fixture（会话、选中节点、场景开关）。
- `test_functional.py`：功能用例（F-001 ~ F-008）。
- `test_exceptions.py`：异常用例（E-001 ~ E-006）。
- `test_performance.py`：性能用例（P-001 ~ P-002）。
- `test_stability.py`：稳定性用例（S-001 ~ S-002）。

## 运行前准备

设置 MCP 服务地址：

```bash
export LOOKIN_MCP_TEST_BASE_URL="http://127.0.0.1:4010/mcp/tool"
```

可选配置：

```bash
export LOOKIN_MCP_TEST_TIMEOUT_SEC=15
```

手工场景开关（默认关闭，避免误报）：

```bash
export LOOKIN_MCP_SCENARIO_NO_SESSION=1
export LOOKIN_MCP_SCENARIO_NO_SELECTION=1
export LOOKIN_MCP_SCENARIO_SCREENSHOT_FAIL=1
export LOOKIN_MCP_SCENARIO_SESSION_SWITCH=1
```

## 执行命令

```bash
pytest lookin-mcp/tests -q
```

按类别执行：

```bash
pytest lookin-mcp/tests -m functional -q
pytest lookin-mcp/tests -m exception -q
pytest lookin-mcp/tests -m performance -q
pytest lookin-mcp/tests -m stability -q
```

只跑单个编号：

```bash
pytest lookin-mcp/tests/test_functional.py -k F_004 -q
pytest lookin-mcp/tests/test_exceptions.py -k E_003 -q
```

## 本地开发建议

- `functional + exception` 作为本地阻塞门禁。
- `performance + stability` 作为非阻塞参考（本地开发态默认阈值已放宽，可通过环境变量自行收紧）。
