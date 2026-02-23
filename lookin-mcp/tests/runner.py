from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


def _env_float(name: str, default: float) -> float:
    raw = os.getenv(name, "").strip()
    if not raw:
        return default
    try:
        return float(raw)
    except ValueError:
        return default

def _env_flag(name: str) -> bool:
    raw = os.getenv(name, "").strip().lower()
    return raw in {"1", "true", "yes", "on"}


@dataclass
class ToolResult:
    ok: bool
    status_code: int
    content: dict[str, Any] | None
    error: dict[str, Any] | None
    raw: Any


def extract_error_code(result: ToolResult) -> str | None:
    if not result.error:
        return None
    code = result.error.get("code")
    return code if isinstance(code, str) else None


class MCPTestClient:
    def __init__(self, base_url: str | None = None, timeout_sec: float | None = None) -> None:
        self.base_url = base_url or os.getenv(
            "LOOKIN_MCP_TEST_BASE_URL",
            "http://127.0.0.1:4010/mcp/tool",
        )
        self.timeout_sec = timeout_sec if timeout_sec is not None else _env_float(
            "LOOKIN_MCP_TEST_TIMEOUT_SEC",
            15.0,
        )

    def invoke(self, tool_name: str, arguments: dict[str, Any] | None = None) -> ToolResult:
        safe_arguments = dict(arguments or {})
        scenario_flags = {
            "LOOKIN_MCP_SCENARIO_NO_SESSION": _env_flag("LOOKIN_MCP_SCENARIO_NO_SESSION"),
            "LOOKIN_MCP_SCENARIO_NO_SELECTION": _env_flag("LOOKIN_MCP_SCENARIO_NO_SELECTION"),
            "LOOKIN_MCP_SCENARIO_SCREENSHOT_FAIL": _env_flag("LOOKIN_MCP_SCENARIO_SCREENSHOT_FAIL"),
            "LOOKIN_MCP_SCENARIO_SESSION_SWITCH": _env_flag("LOOKIN_MCP_SCENARIO_SESSION_SWITCH"),
        }
        if any(scenario_flags.values()):
            safe_arguments["_scenarioFlags"] = scenario_flags

        payload = {
            "name": tool_name,
            "arguments": safe_arguments,
        }
        body_bytes = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(
            self.base_url,
            data=body_bytes,
            method="POST",
            headers={"Content-Type": "application/json"},
        )

        try:
            with urllib.request.urlopen(request, timeout=self.timeout_sec) as response:
                status = response.getcode()
                raw_body = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            status = exc.code
            raw_body = exc.read().decode("utf-8")
        except urllib.error.URLError as exc:
            return ToolResult(
                ok=False,
                status_code=0,
                content=None,
                error={
                    "code": "LOOKIN_MCP_TRANSPORT_ERROR",
                    "message": str(exc.reason),
                    "recoverable": True,
                    "hint": "Check LOOKIN_MCP_TEST_BASE_URL and server status.",
                },
                raw=None,
            )

        parsed = self._parse_json(raw_body)
        return self._normalize(parsed, status)

    @staticmethod
    def _parse_json(raw_body: str) -> Any:
        raw_body = raw_body.strip()
        if not raw_body:
            return {}
        try:
            return json.loads(raw_body)
        except json.JSONDecodeError:
            return {"_raw_text": raw_body}

    def _normalize(self, payload: Any, status_code: int) -> ToolResult:
        if isinstance(payload, dict):
            if "error" in payload:
                return ToolResult(
                    ok=False,
                    status_code=status_code,
                    content=None,
                    error=self._normalize_error(payload.get("error")),
                    raw=payload,
                )

            if "result" in payload and isinstance(payload["result"], dict):
                result = payload["result"]
                if "structuredContent" in result and isinstance(result["structuredContent"], dict):
                    return ToolResult(
                        ok=True,
                        status_code=status_code,
                        content=result["structuredContent"],
                        error=None,
                        raw=payload,
                    )
                if self._looks_like_error(result):
                    return ToolResult(
                        ok=False,
                        status_code=status_code,
                        content=None,
                        error=self._normalize_error(result),
                        raw=payload,
                    )
                return ToolResult(
                    ok=True,
                    status_code=status_code,
                    content=result,
                    error=None,
                    raw=payload,
                )

            if "structuredContent" in payload and isinstance(payload["structuredContent"], dict):
                return ToolResult(
                    ok=True,
                    status_code=status_code,
                    content=payload["structuredContent"],
                    error=None,
                    raw=payload,
                )

            if self._looks_like_error(payload):
                return ToolResult(
                    ok=False,
                    status_code=status_code,
                    content=None,
                    error=self._normalize_error(payload),
                    raw=payload,
                )

            return ToolResult(
                ok=True,
                status_code=status_code,
                content=payload,
                error=None,
                raw=payload,
            )

        return ToolResult(
            ok=False,
            status_code=status_code,
            content=None,
            error={
                "code": "LOOKIN_MCP_BAD_RESPONSE",
                "message": f"Unexpected response type: {type(payload).__name__}",
                "recoverable": False,
            },
            raw=payload,
        )

    @staticmethod
    def _looks_like_error(obj: dict[str, Any]) -> bool:
        code = obj.get("code")
        msg = obj.get("message")
        return isinstance(code, str) and isinstance(msg, str)

    def _normalize_error(self, error_obj: Any) -> dict[str, Any]:
        if isinstance(error_obj, dict):
            if "data" in error_obj and isinstance(error_obj["data"], dict):
                data = dict(error_obj["data"])
                if isinstance(error_obj.get("code"), str) and "code" not in data:
                    data["code"] = error_obj["code"]
                if isinstance(error_obj.get("message"), str) and "message" not in data:
                    data["message"] = error_obj["message"]
                return data
            return dict(error_obj)
        return {"code": "LOOKIN_MCP_UNKNOWN_ERROR", "message": str(error_obj)}
