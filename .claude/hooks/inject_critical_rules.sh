#!/usr/bin/env bash
# Re-inject Chapterly's most-violated CLAUDE.md rules so they survive:
#   - mid-session attention drift  (registered on UserPromptSubmit: every turn)
#   - context compaction           (registered on PreCompact: before summarize)
# Claude Code loads CLAUDE.md natively ONCE at session start; this hook counters
# the "ignores CLAUDE.md mid-session" drift that happens AFTER that point.
# Rules live in critical_rules.txt (single source — shared by both registrations).
# $1 = hookEventName (UserPromptSubmit | PreCompact).
set -uo pipefail

EVENT="${1:-UserPromptSubmit}"
DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_FILE="$DIR/critical_rules.txt"
[ -f "$RULES_FILE" ] || exit 0

FP_RULES="$(cat "$RULES_FILE")" FP_EVENT="$EVENT" python3 - <<'PY'
import json, os
rules = os.environ.get("FP_RULES", "").strip()
event = os.environ.get("FP_EVENT", "UserPromptSubmit")
if not rules:
    raise SystemExit(0)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": event,
    "additionalContext": rules,
}}, ensure_ascii=False))
PY
