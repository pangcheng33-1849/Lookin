from __future__ import annotations

import os
from pathlib import Path
from typing import Callable

import pytest

from runner import MCPTestClient, extract_error_code


def _flag_enabled(name: str) -> bool:
    return os.getenv(name, "").strip().lower() in {"1", "true", "yes", "on"}


def _png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a valid PNG file: {path}")
    width = int.from_bytes(data[16:20], "big")
    height = int.from_bytes(data[20:24], "big")
    return width, height


@pytest.fixture(scope="session")
def mcp_client() -> MCPTestClient:
    return MCPTestClient()


@pytest.fixture(scope="session")
def require_scenario() -> Callable[[str], None]:
    def _require(flag_name: str) -> None:
        if not _flag_enabled(flag_name):
            pytest.skip(f"scenario not enabled: export {flag_name}=1")

    return _require


@pytest.fixture()
def active_session(mcp_client: MCPTestClient) -> dict:
    result = mcp_client.invoke("lookin.health")
    assert result.ok, f"lookin.health failed: {result.error or result.raw}"
    assert isinstance(result.content, dict), f"unexpected health content: {result.raw}"
    status = result.content.get("status")
    if status != "ok":
        pytest.skip("requires active Lookin session (status=ok)")
    return result.content


@pytest.fixture()
def selected_context(mcp_client: MCPTestClient, active_session: dict) -> dict:
    _ = active_session
    result = mcp_client.invoke("lookin.get_selected_view_context", {"childrenDepth": 1})
    if not result.ok and extract_error_code(result) == "LOOKIN_MCP_NO_SELECTION":
        pytest.skip("requires selected view in Lookin")
    assert result.ok, f"get_selected_view_context failed: {result.error or result.raw}"
    assert isinstance(result.content, dict), f"unexpected context content: {result.raw}"
    return result.content


@pytest.fixture(scope="session")
def png_size() -> Callable[[Path], tuple[int, int]]:
    return _png_size
