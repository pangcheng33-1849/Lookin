from __future__ import annotations

import time
from pathlib import Path
from typing import Any
from uuid import uuid4

import pytest

from runner import MCPTestClient


def _contains_key(obj: Any, target_key: str) -> bool:
    if isinstance(obj, dict):
        if target_key in obj:
            return True
        return any(_contains_key(v, target_key) for v in obj.values())
    if isinstance(obj, list):
        return any(_contains_key(item, target_key) for item in obj)
    return False


def _new_req_id(prefix: str) -> str:
    return f"{prefix}-{int(time.time() * 1000)}-{uuid4().hex[:6]}"


def _selected_node_id(selected_context: dict[str, Any]) -> str:
    identity = selected_context.get("selectedNode", {}).get("identity", {})
    node_id = identity.get("nodeId")
    assert isinstance(node_id, str) and node_id, "selectedNode.identity.nodeId should be non-empty string"
    return node_id


def _assert_hierarchy_node_contract(node: dict[str, Any]) -> None:
    assert set(node.keys()) == {"nodeId", "className", "ivarNameOfParent", "hasChildren", "children"}
    assert isinstance(node["nodeId"], str)
    assert isinstance(node["className"], str)
    assert isinstance(node["ivarNameOfParent"], str)
    assert isinstance(node["hasChildren"], bool)
    assert isinstance(node["children"], list)
    for child in node["children"]:
        assert isinstance(child, dict)
        _assert_hierarchy_node_contract(child)


@pytest.mark.functional
def test_F_001_health(mcp_client: MCPTestClient) -> None:
    result = mcp_client.invoke("lookin.health")
    assert result.ok, f"health failed: {result.error or result.raw}"
    assert isinstance(result.content, dict)
    assert result.content.get("status") in {"ok", "no_session"}
    assert isinstance(result.content.get("timestamp"), int)

    if result.content.get("status") == "ok":
        assert isinstance(result.content.get("sessionId"), str)
        assert result.content["sessionId"]


@pytest.mark.functional
def test_F_002_get_selected_view_context_schema(selected_context: dict) -> None:
    assert "session" in selected_context
    assert "selectedNode" in selected_context
    assert "dashboard" in selected_context["selectedNode"]

    groups = selected_context["selectedNode"]["dashboard"].get("groups")
    assert isinstance(groups, list)
    assert groups, "dashboard.groups should not be empty for selected node"
    assert not _contains_key(selected_context, "quality"), "quality field should not exist"

    attrs: list[dict[str, Any]] = []
    for group in groups:
        for section in group.get("sections", []):
            attrs.extend(section.get("attributes", []))
    assert attrs, "dashboard attributes should not be empty for selected node"
    for attr in attrs:
        assert isinstance(attr.get("attrTitle"), str) and attr["attrTitle"], "attrTitle should be non-empty string"
        assert "attrType" not in attr, "attrType should not be returned"

    constraint_attrs = [attr for attr in attrs if attr.get("attrIdentifier") == "al_c_c"]
    for attr in constraint_attrs:
        value = attr.get("value")
        assert isinstance(value, list), "al_c_c value should be list"
        for item in value:
            assert isinstance(item, dict), "constraint item should be parsed object"
            assert isinstance(item.get("expression"), str) and item["expression"], "constraint expression should be non-empty"


@pytest.mark.functional
def test_F_003_children_depth_behavior(
    mcp_client: MCPTestClient,
    selected_context: dict,
) -> None:
    _ = selected_context
    d0 = mcp_client.invoke("lookin.get_selected_view_context", {"childrenDepth": 0})
    d1 = mcp_client.invoke("lookin.get_selected_view_context", {"childrenDepth": 1})

    assert d0.ok, f"childrenDepth=0 failed: {d0.error or d0.raw}"
    assert d1.ok, f"childrenDepth=1 failed: {d1.error or d1.raw}"

    n0 = d0.content["selectedNode"]
    n1 = d1.content["selectedNode"]
    assert "identity" in n0 and "dashboard" in n0
    assert "identity" in n1 and "dashboard" in n1

    hints0 = n0.get("structureHints", {})
    hints1 = n1.get("structureHints", {})
    c0 = hints0.get("childrenSummary", [])
    c1 = hints1.get("childrenSummary", [])
    if isinstance(c0, list) and isinstance(c1, list):
        assert len(c1) >= len(c0)


@pytest.mark.functional
def test_F_004_append_requirement_items(
    mcp_client: MCPTestClient,
    active_session: dict,
) -> None:
    _ = active_session
    rid1 = _new_req_id("F4")
    rid2 = _new_req_id("F4")
    items = [
        {"requirementId": rid1, "description": "TDD F-004 item 1"},
        {"requirementId": rid2, "description": "TDD F-004 item 2"},
    ]

    try:
        result = mcp_client.invoke(
            "lookin.set_requirement_items",
            {"operation": "append", "items": items},
        )
        assert result.ok, f"append failed: {result.error or result.raw}"
        assert result.content.get("operation") == "append"
        assert isinstance(result.content.get("total"), int)
        assert result.content["total"] >= 2
        returned_ids = {item["requirementId"] for item in result.content.get("items", [])}
        assert rid1 in returned_ids
        assert rid2 in returned_ids
    finally:
        mcp_client.invoke(
            "lookin.set_requirement_items",
            {
                "operation": "remove",
                "items": [{"requirementId": rid1}, {"requirementId": rid2}],
            },
        )


@pytest.mark.functional
def test_F_005_remove_requirement_items(
    mcp_client: MCPTestClient,
    active_session: dict,
) -> None:
    _ = active_session
    rid1 = _new_req_id("F5")
    rid2 = _new_req_id("F5")
    append = mcp_client.invoke(
        "lookin.set_requirement_items",
        {
            "operation": "append",
            "items": [
                {"requirementId": rid1, "description": "TDD F-005 keep"},
                {"requirementId": rid2, "description": "TDD F-005 remove"},
            ],
        },
    )
    assert append.ok, f"append precondition failed: {append.error or append.raw}"
    before_total = append.content["total"]

    try:
        remove = mcp_client.invoke(
            "lookin.set_requirement_items",
            {"operation": "remove", "items": [{"requirementId": rid2}]},
        )
        assert remove.ok, f"remove failed: {remove.error or remove.raw}"
        assert remove.content.get("operation") == "remove"
        assert remove.content.get("total") == before_total - 1

        code_info = mcp_client.invoke("lookin.get_requirement_code_info")
        assert code_info.ok, f"get code info failed: {code_info.error or code_info.raw}"
        bound_ids = {record["requirementId"] for record in code_info.content.get("records", [])}
        assert rid2 not in bound_ids
    finally:
        mcp_client.invoke(
            "lookin.set_requirement_items",
            {
                "operation": "remove",
                "items": [{"requirementId": rid1}, {"requirementId": rid2}],
            },
        )


@pytest.mark.functional
def test_F_006_get_requirement_code_info_contract(
    mcp_client: MCPTestClient,
    active_session: dict,
) -> None:
    _ = active_session
    result = mcp_client.invoke("lookin.get_requirement_code_info")
    assert result.ok, f"get code info failed: {result.error or result.raw}"

    records = result.content.get("records")
    assert isinstance(records, list)
    for record in records:
        assert set(record.keys()) == {"requirementId", "description", "codeInfo"}
        assert isinstance(record["codeInfo"], str)


@pytest.mark.functional
def test_F_007_capture_selected_view_screenshot(
    mcp_client: MCPTestClient,
    selected_context: dict,
    png_size,
) -> None:
    _ = selected_context
    result = mcp_client.invoke("lookin.capture_selected_view_screenshot", {"format": "png"})
    assert result.ok, f"capture screenshot failed: {result.error or result.raw}"

    path = Path(result.content["path"])
    assert path.exists(), f"screenshot file not found: {path}"
    width, height = png_size(path)
    assert width > 0 and height > 0
    assert result.content["width"] > 0 and result.content["height"] > 0


@pytest.mark.functional
def test_F_008_code_info_visible_within_1s(
    mcp_client: MCPTestClient,
    active_session: dict,
) -> None:
    _ = active_session
    rid = _new_req_id("F8")
    append = mcp_client.invoke(
        "lookin.set_requirement_items",
        {
            "operation": "append",
            "items": [{"requirementId": rid, "description": "F8 SLA"}],
        },
    )
    assert append.ok, f"append failed: {append.error or append.raw}"

    found = False
    deadline = time.monotonic() + 1.0
    try:
        while time.monotonic() <= deadline:
            result = mcp_client.invoke("lookin.get_requirement_code_info")
            assert result.ok, f"get code info failed: {result.error or result.raw}"
            records = result.content.get("records", [])
            found = any(record.get("requirementId") == rid for record in records)
            if found:
                break
            time.sleep(0.05)
    finally:
        mcp_client.invoke(
            "lookin.set_requirement_items",
            {"operation": "remove", "items": [{"requirementId": rid}]},
        )

    assert found, "new requirement item was not visible within 1s"


@pytest.mark.functional
def test_F_009_get_hierarchy_by_node_id_roots_default(
    mcp_client: MCPTestClient,
    active_session: dict,
) -> None:
    _ = active_session
    result = mcp_client.invoke("lookin.get_hierarchy_by_node_id", {"depth": 1})
    assert result.ok, f"get_hierarchy_by_node_id failed: {result.error or result.raw}"

    hierarchy = result.content.get("hierarchy", {})
    assert hierarchy.get("startFrom") == "roots"
    assert hierarchy.get("depth") == 1
    nodes = hierarchy.get("nodes")
    assert isinstance(nodes, list)
    for node in nodes:
        assert isinstance(node, dict)
        _assert_hierarchy_node_contract(node)


@pytest.mark.functional
def test_F_010_get_hierarchy_by_node_id_depth_behavior(
    mcp_client: MCPTestClient,
    selected_context: dict,
) -> None:
    node_id = _selected_node_id(selected_context)
    d0 = mcp_client.invoke("lookin.get_hierarchy_by_node_id", {"nodeId": node_id, "depth": 0})
    d1 = mcp_client.invoke("lookin.get_hierarchy_by_node_id", {"nodeId": node_id, "depth": 1})
    assert d0.ok, f"depth=0 failed: {d0.error or d0.raw}"
    assert d1.ok, f"depth=1 failed: {d1.error or d1.raw}"

    h0 = d0.content["hierarchy"]
    h1 = d1.content["hierarchy"]
    assert h0["startFrom"] == "node"
    assert h1["startFrom"] == "node"
    assert h0["startNodeId"] == node_id
    assert h1["startNodeId"] == node_id
    assert h0["depth"] == 0
    assert h1["depth"] == 1

    node0 = h0["nodes"][0]
    node1 = h1["nodes"][0]
    _assert_hierarchy_node_contract(node0)
    _assert_hierarchy_node_contract(node1)
    assert node0["children"] == []
    assert len(node1["children"]) >= len(node0["children"])
    if len(node1["children"]) > 0:
        assert node0["hasChildren"] is True


@pytest.mark.functional
def test_F_011_get_view_context_by_node_id_matches_selected_node(
    mcp_client: MCPTestClient,
    selected_context: dict,
) -> None:
    node_id = _selected_node_id(selected_context)
    result = mcp_client.invoke(
        "lookin.get_view_context_by_node_id",
        {"nodeId": node_id, "childrenDepth": 1},
    )
    assert result.ok, f"get_view_context_by_node_id failed: {result.error or result.raw}"
    assert "targetNode" in result.content
    assert result.content["targetNode"] == selected_context["selectedNode"]


@pytest.mark.functional
def test_F_012_capture_view_screenshot_by_node_id_matches_contract(
    mcp_client: MCPTestClient,
    selected_context: dict,
    png_size,
) -> None:
    node_id = _selected_node_id(selected_context)

    selected_result = mcp_client.invoke("lookin.capture_selected_view_screenshot", {"format": "png"})
    by_node_result = mcp_client.invoke(
        "lookin.capture_view_screenshot_by_node_id",
        {"nodeId": node_id, "format": "png"},
    )
    assert selected_result.ok, f"capture_selected_view_screenshot failed: {selected_result.error or selected_result.raw}"
    assert by_node_result.ok, f"capture_view_screenshot_by_node_id failed: {by_node_result.error or by_node_result.raw}"

    selected_payload = selected_result.content
    by_node_payload = by_node_result.content
    assert set(selected_payload.keys()) == set(by_node_payload.keys())
    assert by_node_payload["nodeId"] == node_id
    assert selected_payload["sessionId"] == by_node_payload["sessionId"]
    assert selected_payload["format"] == by_node_payload["format"] == "png"

    path = Path(by_node_payload["path"])
    assert path.exists(), f"screenshot file not found: {path}"
    width, height = png_size(path)
    assert width > 0 and height > 0
    assert by_node_payload["width"] > 0 and by_node_payload["height"] > 0
