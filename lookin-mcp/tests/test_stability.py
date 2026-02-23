from __future__ import annotations

import os
import time
from uuid import uuid4

import pytest

from runner import MCPTestClient, extract_error_code


def _new_req_id(prefix: str) -> str:
    return f"{prefix}-{int(time.time() * 1000)}-{uuid4().hex[:6]}"


@pytest.mark.stability
def test_S_001_mixed_calls_100_rounds(
    mcp_client: MCPTestClient,
    selected_context: dict,
) -> None:
    _ = selected_context
    rounds = int(os.getenv("LOOKIN_MCP_STABILITY_ROUNDS", "30"))
    failures = []

    for i in range(rounds):
        rid = _new_req_id(f"S1-{i}")
        checks = [
            ("lookin.health", {}),
            ("lookin.get_selected_view_context", {"childrenDepth": 1}),
            (
                "lookin.set_requirement_items",
                {
                    "operation": "append",
                    "items": [{"requirementId": rid, "description": f"S1 item {i}"}],
                },
            ),
            ("lookin.get_requirement_code_info", {}),
            ("lookin.capture_selected_view_screenshot", {"format": "png"}),
            (
                "lookin.set_requirement_items",
                {"operation": "remove", "items": [{"requirementId": rid}]},
            ),
        ]

        for tool_name, args in checks:
            result = mcp_client.invoke(tool_name, args)
            if not result.ok:
                failures.append((i, tool_name, result.error))
                break

    assert not failures, f"mixed calls failed: {failures[:3]}"


@pytest.mark.stability
def test_S_002_session_switch_recovery(
    mcp_client: MCPTestClient,
    require_scenario,
) -> None:
    require_scenario("LOOKIN_MCP_SCENARIO_SESSION_SWITCH")
    rounds = int(os.getenv("LOOKIN_MCP_SESSION_SWITCH_ROUNDS", "10"))
    unexpected_errors = []

    for i in range(rounds):
        for tool_name, args in [
            ("lookin.health", {}),
            ("lookin.get_selected_view_context", {"childrenDepth": 1}),
            ("lookin.get_requirement_code_info", {}),
            ("lookin.capture_selected_view_screenshot", {"format": "png"}),
        ]:
            result = mcp_client.invoke(tool_name, args)
            if result.ok:
                continue
            code = extract_error_code(result)
            if code not in {"LOOKIN_MCP_NO_SESSION", "LOOKIN_MCP_NO_SELECTION"}:
                unexpected_errors.append((i, tool_name, result.error))

    assert not unexpected_errors, f"unexpected errors after session switch: {unexpected_errors[:3]}"
