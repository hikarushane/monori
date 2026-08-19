#!/usr/bin/env bash
# Regression guard for fa5bb64.
#
# The verify.sh PreToolUse hook's `if` gate ("Bash(git commit *)") MUST live
# INSIDE the hook command object (next to `command`/`timeout`), NOT as a sibling
# of `matcher`. When `if` sits at the matcher level Claude Code does not
# recognize it, so verify.sh (full iOS build + MonoriCore tests) fires on
# EVERY Bash command instead of only on `git commit` — an effective lockup.
#
# This check fails loudly if that nesting ever regresses. It is run as Step 0 of
# verify.sh, so every commit re-validates the hook config before the costly build.
#
# Also checks that Codex delegates to the Claude hook source via the repo-local
# adapter, instead of carrying a second copy of hook commands.
#
# Usage: check-hooks.sh [path/to/settings.json]   (defaults to repo .claude/settings.json)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS="${1:-$PROJECT_DIR/.claude/settings.json}"
CODEX_HOOKS="$PROJECT_DIR/.codex/hooks.json"
AGENTS="$PROJECT_DIR/AGENTS.md"
CODEX_ADAPTER="$PROJECT_DIR/scripts/codex-hook-adapter.py"

if [ ! -f "$SETTINGS" ]; then
  echo "check-hooks: $SETTINGS not found — skipping (no repo Claude hooks here)"
  exit 0
fi

python3 - "$PROJECT_DIR" "$SETTINGS" "$CODEX_HOOKS" "$AGENTS" "$CODEX_ADAPTER" <<'PY'
import json, subprocess, sys
from pathlib import Path

project_dir = Path(sys.argv[1])
settings_path = Path(sys.argv[2])
codex_hooks_path = Path(sys.argv[3])
agents_path = Path(sys.argv[4])
codex_adapter_path = Path(sys.argv[5])

with settings_path.open() as f:
    cfg = json.load(f)

claude_hooks = cfg.get("hooks", {})
pre = claude_hooks.get("PreToolUse", [])
errors = []
claude_dir = settings_path.parent

# 1) `if` must never be a sibling of `matcher` (the fa5bb64 bug).
for i, entry in enumerate(pre):
    if "if" in entry:
        errors.append(
            f"PreToolUse[{i}]: `if` is a sibling of `matcher` — this is the "
            f"fa5bb64 regression. Move `if` inside the hook command object."
        )

# 2) The verify.sh hook must keep its gate `if` inside the command object.
verify_hooks = [
    h
    for entry in pre
    for h in entry.get("hooks", [])
    if "verify.sh" in h.get("command", "")
]
if not verify_hooks:
    errors.append("verify.sh PreToolUse hook not found in .claude/settings.json.")
else:
    for h in verify_hooks:
        gate = h.get("if")
        if gate != "Bash(git commit *)":
            errors.append(
                "verify.sh hook: expected `if` == 'Bash(git commit *)' inside the "
                f"command object, got {gate!r}."
            )
        # `if` alone fails OPEN on complex compound commands (for-loops / quoted
        # inner `;`), so the command MUST also carry an internal stdin guard that
        # re-checks for a real `git commit` before running the costly verify.sh.
        cmd = h.get("command", "")
        if "tool_input.command" not in cmd or "git" not in cmd:
            errors.append(
                "verify.sh hook: missing internal stdin git-commit guard. Expected the "
                "command to read `.tool_input.command` (jq) and grep for a real `git "
                "commit` subcommand, exiting 0 otherwise, BEFORE invoking verify.sh."
            )

if not codex_adapter_path.is_file():
    errors.append("Codex hook adapter missing: scripts/codex-hook-adapter.py.")
else:
    tracked = subprocess.run(
        [
            "git",
            "-C",
            str(project_dir),
            "ls-files",
            "--error-unmatch",
            "--",
            "scripts/codex-hook-adapter.py",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if tracked.returncode != 0:
        errors.append(
            "scripts/codex-hook-adapter.py is referenced by .codex/hooks.json but "
            "is not tracked/staged in git. Stage or commit it before committing "
            "hook config that depends on it."
        )

if not codex_hooks_path.is_file():
    errors.append("Codex hooks file missing: .codex/hooks.json.")
else:
    with codex_hooks_path.open() as f:
        codex_cfg = json.load(f)
    codex_hooks = codex_cfg.get("hooks", {})
    codex_commands_by_event = {}
    for event, entries in codex_hooks.items():
        codex_commands_by_event[event] = [
            h.get("command", "")
            for entry in entries
            for h in entry.get("hooks", [])
            if h.get("type") == "command"
        ]

    missing_events = sorted(set(claude_hooks) - set(codex_hooks))
    if missing_events:
        errors.append(
            ".codex/hooks.json must register every .claude/settings.json hook "
            f"event via the adapter; missing: {', '.join(missing_events)}."
        )

    for event in sorted(claude_hooks):
        commands = codex_commands_by_event.get(event, [])
        if not commands:
            errors.append(f".codex/hooks.json has no command hooks for {event}.")
            continue
        expected_event_arg = f"codex-hook-adapter.py\" {event}"
        if not any("scripts/codex-hook-adapter.py" in cmd and expected_event_arg in cmd for cmd in commands):
            errors.append(
                f".codex/hooks.json {event} hook must call "
                f"scripts/codex-hook-adapter.py {event} so Codex tracks "
                ".claude/settings.json instead of duplicating hook logic."
            )

    for event, commands in codex_commands_by_event.items():
        for cmd in commands:
            if "/Users/" in cmd:
                errors.append(
                    ".codex/hooks.json must not hardcode /Users/ absolute paths; "
                    f"found {event} command: {cmd!r}."
                )

    if codex_adapter_path.is_file():
        adapter = codex_adapter_path.read_text()
        if 'event != "PreToolUse"' in adapter:
            errors.append(
                "scripts/codex-hook-adapter.py still short-circuits non-PreToolUse "
                "events; lifecycle hooks would drift from .claude/settings.json."
            )
        if "synthetic_read_payload" not in adapter or "shell_reads_source" not in adapter:
            errors.append(
                "scripts/codex-hook-adapter.py must translate Codex shell reads "
                "(cat/sed/nl/head/tail/etc.) into the Claude Read|Glob graphify "
                "advisory path."
            )

uncovered_surfaces = []
for surface in ("commands", "agents"):
    path = claude_dir / surface
    if path.is_dir():
        files = [
            p
            for p in path.rglob("*")
            if p.is_file() and p.name != ".DS_Store"
        ]
        if files:
            uncovered_surfaces.append(f".claude/{surface}")

for path in (
    project_dir / ".mcp.json",
    claude_dir / "mcp.json",
    claude_dir / "mcp-servers.json",
    claude_dir / "mcp_servers.json",
):
    if path.exists():
        uncovered_surfaces.append(str(path.relative_to(project_dir)))

if cfg.get("mcpServers"):
    uncovered_surfaces.append(".claude/settings.json:mcpServers")

if uncovered_surfaces:
    errors.append(
        "New Claude asset surfaces need an explicit Codex migration decision: "
        f"{', '.join(sorted(set(uncovered_surfaces)))}. Update AGENTS.md and "
        "scripts/check-hooks.sh so they are either mirrored or documented as "
        "intentionally Claude-only."
    )

if not agents_path.is_file():
    errors.append("AGENTS.md missing.")
else:
    agents = agents_path.read_text()
    for required in (
        "CLAUDE.md",
        "SIMULATOR_PLAYBOOK.md",
        "critical_rules.txt",
        "HANDOFF.md",
        "MEMORY.md",
        ".claude/settings.json",
        ".claude/settings.local.json",
    ):
        if required not in agents:
            errors.append(f"AGENTS.md must reference {required}.")

if errors:
    print("HOOK CONFIG CHECK FAILED (see fa5bb64):")
    for e in errors:
        print("  -", e)
    sys.exit(1)

PY

payload() {
  python3 - "$@" <<'PY'
import json, sys
tool_name, cmd = sys.argv[1], sys.argv[2]
print(json.dumps({"tool_name": tool_name, "tool_input": {"cmd": cmd}}))
PY
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if ! printf '%s' "$haystack" | grep -Fq "$needle"; then
    echo "HOOK CONFIG CHECK FAILED (adapter payload regression):"
    echo "  - $label"
    exit 1
  fi
}

assert_empty() {
  local value="$1"
  local label="$2"
  if [ -n "$value" ]; then
    echo "HOOK CONFIG CHECK FAILED (adapter payload regression):"
    echo "  - $label"
    exit 1
  fi
}

NON_COMMIT_OUT="$(payload functions.exec_command "true" | python3 "$CODEX_ADAPTER" PreToolUse)"
assert_empty "$NON_COMMIT_OUT" "non-commit Bash payload should not emit hook output or run verify.sh."

if [ -f "$PROJECT_DIR/graphify-out/graph.json" ]; then
  SEARCH_OUT="$(payload functions.exec_command "rg TODO App" | python3 "$CODEX_ADAPTER" PreToolUse)"
  assert_contains "$SEARCH_OUT" "MUST run \`graphify query" \
    "Codex Bash search payload should receive the Claude graphify search advisory."

  READ_OUT="$(payload functions.exec_command "nl -ba App/AppRootView.swift" | python3 "$CODEX_ADAPTER" PreToolUse)"
  assert_contains "$READ_OUT" "MUST run graphify before reading source files" \
    "Codex shell source-read payload should receive the Claude Read|Glob graphify advisory."
fi

if [ -f "$PROJECT_DIR/.claude/hooks/critical_rules.txt" ]; then
  PROMPT_OUT="$(printf '{}' | python3 "$CODEX_ADAPTER" UserPromptSubmit)"
  assert_contains "$PROMPT_OUT" '"hookEventName": "UserPromptSubmit"' \
    "UserPromptSubmit should run Claude critical-rules injection through the Codex adapter."

  COMPACT_OUT="$(printf '{}' | python3 "$CODEX_ADAPTER" PreCompact)"
  assert_contains "$COMPACT_OUT" '"hookEventName": "PreCompact"' \
    "PreCompact should run Claude critical-rules injection through the Codex adapter."
fi

echo "hook config OK — Claude hooks and Codex adapter are in sync"
