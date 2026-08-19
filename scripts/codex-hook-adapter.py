#!/usr/bin/env python3
"""Run Codex hooks from Monori's Claude Code hook config.

Claude Code remains the source of truth for project hook behavior. This thin
adapter lets Codex reuse the current `.claude/settings.json` hooks without
copying command strings into `.codex/hooks.json`.
"""

from __future__ import annotations

import fnmatch
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any


PROJECT_DIR = Path(__file__).resolve().parents[1]
SETTINGS_PATH = PROJECT_DIR / ".claude" / "settings.json"
EVENT_ALIASES = {
    # Codex supports Stop, but this keeps the adapter tolerant of clients that
    # phrase end-of-session hooks as SessionEnd.
    "SessionEnd": "Stop",
}
SOURCE_EXTENSIONS = (
    ".py",
    ".js",
    ".ts",
    ".tsx",
    ".jsx",
    ".go",
    ".rs",
    ".java",
    ".rb",
    ".c",
    ".h",
    ".cpp",
    ".hpp",
    ".cc",
    ".cs",
    ".kt",
    ".swift",
    ".php",
    ".scala",
    ".lua",
    ".sh",
    ".md",
    ".rst",
    ".txt",
    ".mdx",
)
SHELL_READ_RE = re.compile(
    r"(^|[;&|]\s*)(cat|sed|nl|head|tail|less|more|bat|batcat|awk)\b"
)


def load_payload() -> tuple[str, dict[str, Any]]:
    raw = sys.stdin.read()
    if not raw.strip():
        return "{}", {}
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return raw, {}
    return raw, payload if isinstance(payload, dict) else {}


def tool_name(payload: dict[str, Any]) -> str:
    name = str(payload.get("tool_name") or payload.get("tool") or "")
    tool_input = payload.get("tool_input") or {}
    if name in {"functions.exec_command", "exec_command"} and isinstance(tool_input, dict):
        return "Bash"
    return name


def tool_command(payload: dict[str, Any]) -> str:
    tool_input = payload.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return ""
    return str(tool_input.get("command") or tool_input.get("cmd") or "")


def claude_payload(raw_payload: str, payload: dict[str, Any], name: str, command: str) -> str:
    compat = dict(payload) if payload else {}
    compat.setdefault("cwd", str(PROJECT_DIR))

    if name:
        compat["tool_name"] = name

    tool_input = compat.get("tool_input")
    if isinstance(tool_input, dict):
        compat_input = dict(tool_input)
        if command and not compat_input.get("command"):
            compat_input["command"] = command
        compat["tool_input"] = compat_input

    return json.dumps(compat) if compat else raw_payload


def shell_reads_source(command: str) -> bool:
    normalized = command.lower().replace("\\", "/")
    if "graphify-out/" in normalized:
        return False
    return bool(SHELL_READ_RE.search(command)) and any(
        ext in normalized for ext in SOURCE_EXTENSIONS
    )


def synthetic_read_payload(payload: dict[str, Any], command: str) -> str:
    compat = dict(payload) if payload else {}
    compat.setdefault("cwd", str(PROJECT_DIR))
    compat["tool_name"] = "Read"
    compat["tool_input"] = {"file_path": command}
    return json.dumps(compat)


def matcher_matches(pattern: str, name: str) -> bool:
    if pattern in {"", "*", ".*"}:
        return True
    try:
        return re.fullmatch(pattern, name) is not None
    except re.error:
        return fnmatch.fnmatch(name, pattern)


def hook_if_matches(condition: str | None, name: str, command: str) -> bool:
    if not condition:
        return True

    match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)\((.*)\)", condition)
    if not match:
        return True

    expected_tool, command_pattern = match.groups()
    if expected_tool != name:
        return False

    if command_pattern == "git commit *":
        return re.search(r"(^|[;&|]\s*)git\s+commit(\s|$)", command) is not None

    return fnmatch.fnmatch(command, command_pattern)


def run_command(command: str, raw_payload: str, timeout: int | None) -> int:
    env = os.environ.copy()
    env["CLAUDE_PROJECT_DIR"] = str(PROJECT_DIR)

    try:
        result = subprocess.run(
            command,
            input=raw_payload,
            text=True,
            shell=True,
            cwd=PROJECT_DIR,
            env=env,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        if exc.stdout:
            sys.stdout.write(exc.stdout)
        if exc.stderr:
            sys.stderr.write(exc.stderr)
        sys.stderr.write(f"codex-hook-adapter: hook timed out after {timeout}s\n")
        return 2

    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)
    return result.returncode


def main() -> int:
    event = sys.argv[1] if len(sys.argv) > 1 else "PreToolUse"
    if not SETTINGS_PATH.exists():
        return 0
    claude_event = EVENT_ALIASES.get(event, event)

    raw_payload, payload = load_payload()
    name = tool_name(payload)
    command = tool_command(payload)
    hook_payload = claude_payload(raw_payload, payload, name, command)

    with SETTINGS_PATH.open() as handle:
        settings = json.load(handle)

    invocations = [(name, hook_payload)]
    if claude_event == "PreToolUse" and name == "Bash" and shell_reads_source(command):
        invocations.append(("Read", synthetic_read_payload(payload, command)))

    for entry in settings.get("hooks", {}).get(claude_event, []):
        selected: tuple[str, str] | None = None
        for invocation_name, invocation_payload in invocations:
            if matcher_matches(str(entry.get("matcher", "")), invocation_name):
                selected = (invocation_name, invocation_payload)
                break
        if selected is None:
            continue

        invocation_name, invocation_payload = selected
        for hook in entry.get("hooks", []):
            if hook.get("type") != "command":
                continue
            hook_command = hook.get("command")
            if not hook_command:
                continue
            if not hook_if_matches(hook.get("if"), invocation_name, command):
                continue
            timeout = hook.get("timeout")
            code = run_command(
                hook_command,
                invocation_payload,
                timeout if isinstance(timeout, int) else None,
            )
            if code != 0:
                return code

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
