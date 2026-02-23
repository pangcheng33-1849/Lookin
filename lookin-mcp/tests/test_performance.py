from __future__ import annotations

import os
import time
from uuid import uuid4

import pytest

from runner import MCPTestClient


def _p95(values: list[float]) -> float:
    if not values:
        return 0.0
    sorted_values = sorted(values)
    idx = max(int(len(sorted_values) * 0.95) - 1, 0)
    return sorted_values[idx]


def _new_req_id(prefix: str, i: int) -> str:
    return f"{prefix}-{int(time.time() * 1000)}-{i}-{uuid4().hex[:4]}"


@pytest.mark.performance
def test_P_001_selected_context_p95(
    mcp_client: MCPTestClient,
    selected_context: dict,
) -> None:
    _ = selected_context
    warmup = 10
    measure = 50
    threshold = float(os.getenv("LOOKIN_MCP_P95_CONTEXT_SEC", "3.0"))

    for _ in range(warmup):
        result = mcp_client.invoke("lookin.get_selected_view_context", {"childrenDepth": 1})
        assert result.ok, f"warmup failed: {result.error or result.raw}"

    costs = []
    for _ in range(measure):
        start = time.perf_counter()
        result = mcp_client.invoke("lookin.get_selected_view_context", {"childrenDepth": 1})
        end = time.perf_counter()
        assert result.ok, f"measure failed: {result.error or result.raw}"
        costs.append(end - start)

    assert _p95(costs) <= threshold, f"P95={_p95(costs):.3f}s > {threshold:.3f}s"


@pytest.mark.performance
def test_P_002_bindings_p95(
    mcp_client: MCPTestClient,
    active_session: dict,
) -> None:
    _ = active_session
    threshold = float(os.getenv("LOOKIN_MCP_P95_BINDINGS_SEC", "2.0"))
    req_count = int(os.getenv("LOOKIN_MCP_BINDINGS_REQ_COUNT", "50"))
    read_count = int(os.getenv("LOOKIN_MCP_BINDINGS_READ_COUNT", "50"))

    prefix = f"P2-{int(time.time() * 1000)}"
    items = [
        {"requirementId": _new_req_id(prefix, i), "description": f"P2 item {i}"}
        for i in range(req_count)
    ]
    remove_items = [{"requirementId": item["requirementId"]} for item in items]

    append = mcp_client.invoke(
        "lookin.set_requirement_items",
        {"operation": "append", "items": items},
    )
    assert append.ok, f"append {req_count} requirements failed: {append.error or append.raw}"

    try:
        costs = []
        for _ in range(read_count):
            start = time.perf_counter()
            result = mcp_client.invoke("lookin.get_requirement_bindings")
            end = time.perf_counter()
            assert result.ok, f"get bindings failed: {result.error or result.raw}"
            costs.append(end - start)

        assert _p95(costs) <= threshold, f"P95={_p95(costs):.3f}s > {threshold:.3f}s"
    finally:
        mcp_client.invoke(
            "lookin.set_requirement_items",
            {"operation": "remove", "items": remove_items},
        )
