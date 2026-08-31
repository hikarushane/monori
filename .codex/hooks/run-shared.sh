#!/usr/bin/env bash
# Codex adapter: normalize Codex hook stdin to the snake_case keys the existing
# .claude/hooks/* scripts read, then exec the target CC script with the same
# args. Guarantees behavioral parity (same core logic) without duplicating it.
#
# Usage (from .codex/hooks.json):
#   bash .codex/hooks/run-shared.sh <cc-script-relpath> [args...]
# where <cc-script-relpath> is relative to .claude/hooks/ , e.g.
#   inject_critical_rules.sh UserPromptSubmit
#   flow-pack/load_context.sh
#   flow-pack/handoff_update_gate.sh
set -uo pipefail

# Self-locate the repo root from this script's own path (independent of cwd/env).
SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
TARGET_REL="${1:?run-shared.sh: missing target script}"; shift || true
TARGET="$SELF/.claude/hooks/$TARGET_REL"
[ -f "$TARGET" ] || { echo "run-shared.sh: target not found: $TARGET" >&2; exit 0; }

INPUT="$(cat)"
# Normalize camelCase -> snake_case (only add missing keys; never overwrite).
NORM="$(INPUT_JSON="$INPUT" __RUN_SHARED_REPO="$SELF" python3 -c '
import json, os, sys
try:
    d = json.loads(os.environ["INPUT_JSON"])
except Exception:
    sys.exit(0)
if not isinstance(d, dict):
    sys.exit(0)
alias = {"sessionId": "session_id", "toolName": "tool_name", "toolInput": "tool_input"}
for cam, snake in alias.items():
    if cam in d and snake not in d:
        d[snake] = d[cam]
d.setdefault("cwd", os.environ.get("__RUN_SHARED_REPO", ""))
print(json.dumps(d, ensure_ascii=False))
' 2>/dev/null || true)"
[ -n "$NORM" ] || NORM="$INPUT"   # if python failed, pass original through

__RUN_SHARED_REPO="$SELF" exec bash -c 'printf "%s" "$1" | exec bash "$2" "${@:3}"' _ "$NORM" "$TARGET" "$@"
