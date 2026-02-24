from __future__ import annotations

from urllib.parse import urlsplit, urlunsplit

from runner import MCPTestClient


def _initialize(client: MCPTestClient) -> None:
    init = client.invoke_standard_method(
        "initialize",
        {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {
                "name": "lookin-mcp-tests",
                "version": "0.1.0",
            },
        },
        request_id=1001,
    )
    assert init.ok, f"initialize failed: {init.error or init.raw}"
    assert init.content.get("protocolVersion") == "2025-06-18"
    assert isinstance(init.content.get("capabilities"), dict)
    assert isinstance(init.content.get("serverInfo"), dict)

    initialized = client.invoke_standard_method(
        "notifications/initialized",
        {},
        request_id=None,
    )
    assert initialized.ok, f"initialized notification failed: {initialized.error or initialized.raw}"


def test_MCP_001_initialize_lifecycle(mcp_client: MCPTestClient) -> None:
    _initialize(mcp_client)


def test_MCP_002_tools_list(mcp_client: MCPTestClient) -> None:
    _initialize(mcp_client)
    listed = mcp_client.invoke_standard_method("tools/list", {}, request_id=1002)
    assert listed.ok, f"tools/list failed: {listed.error or listed.raw}"
    tools = listed.content.get("tools")
    assert isinstance(tools, list)
    names = {tool.get("name") for tool in tools if isinstance(tool, dict)}
    assert "lookin.health" in names
    assert "lookin.get_selected_view_context" in names
    assert "lookin.set_requirement_items" in names
    assert "lookin.get_requirement_code_info" in names
    assert "lookin.capture_selected_view_screenshot" in names


def test_MCP_003_tools_call_health(mcp_client: MCPTestClient) -> None:
    _initialize(mcp_client)
    called = mcp_client.invoke_standard_method(
        "tools/call",
        {"name": "lookin.health", "arguments": {}},
        request_id=1003,
    )
    assert called.ok, f"tools/call failed: {called.error or called.raw}"
    assert isinstance(called.content, dict)
    assert called.content.get("status") in {"ok", "no_session"}
    assert isinstance(called.content.get("timestamp"), int)


def test_MCP_004_legacy_endpoint_removed(mcp_client: MCPTestClient) -> None:
    split = urlsplit(mcp_client.base_url)
    legacy_url = urlunsplit((split.scheme, split.netloc, "/mcp/tool", split.query, split.fragment))
    legacy = mcp_client.invoke_raw_payload(
        {"name": "lookin.health", "arguments": {}},
        legacy_url,
    )
    assert legacy.status_code == 404
    assert not legacy.ok
