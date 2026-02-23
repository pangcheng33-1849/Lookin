from __future__ import annotations

import time
from uuid import uuid4

import pytest

from runner import MCPTestClient, extract_error_code


def _new_req_id(prefix: str) -> str:
    return f"{prefix}-{int(time.time() * 1000)}-{uuid4().hex[:6]}"


@pytest.mark.exception
def test_E_001_no_session(
    mcp_client: MCPTestClient,
    require_scenario,
) -> None:
    require_scenario("LOOKIN_MCP_SCENARIO_NO_SESSION")

    health = mcp_client.invoke("lookin.health")
    if health.ok:
        assert health.content.get("status") == "no_session"
    else:
        assert extract_error_code(health) == "LOOKIN_MCP_NO_SESSION"

    for tool_name, arguments in [
        ("lookin.get_selected_view_context", {"childrenDepth": 1}),
        ("lookin.get_requirement_code_info", {}),
        ("lookin.capture_selected_view_screenshot", {"format": "png"}),
    ]:
        result = mcp_client.invoke(tool_name, arguments)
        assert not result.ok, f"{tool_name} should fail in no-session scenario"
        assert extract_error_code(result) == "LOOKIN_MCP_NO_SESSION"


@pytest.mark.exception
def test_E_002_no_selection(
    mcp_client: MCPTestClient,
    active_session: dict,
    require_scenario,
) -> None:
    _ = active_session
    require_scenario("LOOKIN_MCP_SCENARIO_NO_SELECTION")

    context = mcp_client.invoke("lookin.get_selected_view_context", {"childrenDepth": 1})
    screenshot = mcp_client.invoke("lookin.capture_selected_view_screenshot", {"format": "png"})

    assert not context.ok
    assert extract_error_code(context) == "LOOKIN_MCP_NO_SELECTION"
    assert not screenshot.ok
    assert extract_error_code(screenshot) == "LOOKIN_MCP_NO_SELECTION"


@pytest.mark.exception
def test_E_003_duplicate_requirement_id(
    mcp_client: MCPTestClient,
    active_session: dict,
) -> None:
    _ = active_session
    dup_id = _new_req_id("E3")
    result = mcp_client.invoke(
        "lookin.set_requirement_items",
        {
            "operation": "append",
            "items": [
                {"requirementId": dup_id, "description": "dup-1"},
                {"requirementId": dup_id, "description": "dup-2"},
            ],
        },
    )
    assert not result.ok
    assert extract_error_code(result) == "LOOKIN_MCP_DUP_REQUIREMENT_ID"


@pytest.mark.exception
def test_E_004_remove_nonexistent_requirement(
    mcp_client: MCPTestClient,
    active_session: dict,
) -> None:
    _ = active_session
    missing_id = _new_req_id("E4-MISSING")
    result = mcp_client.invoke(
        "lookin.set_requirement_items",
        {"operation": "remove", "items": [{"requirementId": missing_id}]},
    )
    assert not result.ok
    assert extract_error_code(result) == "LOOKIN_MCP_REQUIREMENT_NOT_FOUND"


@pytest.mark.exception
@pytest.mark.parametrize(
    ("tool_name", "arguments"),
    [
        ("lookin.get_selected_view_context", {"childrenDepth": -1}),
        ("lookin.set_requirement_items", {"operation": "upsert", "items": [{"requirementId": "X"}]}),
        ("lookin.set_requirement_items", {"operation": "append", "items": [{"requirementId": "X"}]}),
        ("lookin.set_requirement_items", {"operation": "remove", "items": [{}]}),
        ("lookin.capture_selected_view_screenshot", {"format": "jpg"}),
        ("lookin.capture_selected_view_screenshot", {"format": "png", "scale": 0}),
        ("lookin.capture_selected_view_screenshot", {"format": "png", "highlightSelectedRegion": "yes"}),
    ],
)
def test_E_005_bad_argument(
    mcp_client: MCPTestClient,
    active_session: dict,
    tool_name: str,
    arguments: dict,
) -> None:
    _ = active_session
    result = mcp_client.invoke(tool_name, arguments)
    assert not result.ok
    assert extract_error_code(result) == "LOOKIN_MCP_BAD_ARGUMENT"


@pytest.mark.exception
def test_E_006_screenshot_write_failed(
    mcp_client: MCPTestClient,
    active_session: dict,
    require_scenario,
) -> None:
    _ = active_session
    require_scenario("LOOKIN_MCP_SCENARIO_SCREENSHOT_FAIL")
    result = mcp_client.invoke("lookin.capture_selected_view_screenshot", {"format": "png"})
    assert not result.ok
    assert extract_error_code(result) == "LOOKIN_MCP_SCREENSHOT_FAILED"
