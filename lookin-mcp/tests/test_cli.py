from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest


CLI_PATH = (
    Path(__file__).resolve().parents[1]
    / "cli"
    / "bin"
    / "lookinmcp-cli.js"
)


def _run_cli(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["node", str(CLI_PATH), *args],
        text=True,
        capture_output=True,
        check=False,
    )


def test_cli_root_help() -> None:
    result = _run_cli("--help")
    assert result.returncode == 0
    assert "lookinmcp-cli" in result.stdout
    assert "get_selected_view_context" in result.stdout


def test_cli_subcommand_help() -> None:
    result = _run_cli("set_requirement_items", "--help")
    assert result.returncode == 0
    assert "set_requirement_items" in result.stdout
    assert "--operation" in result.stdout
    assert "--items-json" in result.stdout


def test_cli_unknown_command_returns_json_error() -> None:
    result = _run_cli("not_a_command")
    assert result.returncode == 1
    payload = json.loads(result.stderr)
    assert payload["ok"] is False
    assert payload["error"]["code"] == "LOOKINMCP_CLI_BAD_ARGUMENT"


def test_cli_bad_items_json_returns_json_error() -> None:
    result = _run_cli(
        "set_requirement_items",
        "--operation",
        "append",
        "--items-json",
        "{not-json}",
    )
    assert result.returncode == 1
    payload = json.loads(result.stderr)
    assert payload["ok"] is False
    assert payload["error"]["code"] == "LOOKINMCP_CLI_BAD_ARGUMENT"


@pytest.mark.skip(reason="requires running Lookin MCP server on localhost")
def test_cli_health_integration() -> None:
    result = _run_cli("health")
    assert result.returncode == 0
    payload = json.loads(result.stdout)
    assert isinstance(payload, dict)
    assert payload.get("status") in {"ok", "no_session"}
