#!/usr/bin/env bash
# Codex PreToolUse (Bash) commit gate. Mirrors the Claude Code verify.sh commit
# gate: when a real `git commit` is about to run, run scripts/verify.sh; if it
# fails, BLOCK the commit. Codex has no `if:` matcher, so the internal guard
# regex below is the sole trigger (identical regex to the CC inline command),
# avoiding the fa5bb64 false-positive on complex non-commit Bash.
# Blocks via Codex-native permissionDecision:"deny" (proven by pre_tool_use_safety.py).
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"

CMD="$(python3 - <<'PY' 2>/dev/null || true
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
t=d.get("tool_input") or d.get("toolInput") or {}
print(t.get("command","") if isinstance(t,dict) else "")
PY
)"

# Same guard regex as .claude/settings.json: a real `git commit` subcommand at
# command start or right after a ; & | separator (NOT inside quotes/words).
printf '%s' "$CMD" | grep -qE '(^|[;&|][[:space:]]*)git[[:space:]]+commit([[:space:]]|$)' || exit 0

VERIFY="${VERIFY_CMD:-$SELF/scripts/verify.sh}"
mkdir -p "$SELF/build" 2>/dev/null || true
LOG="$SELF/build/verify-hook.log"
if eval "$VERIFY" > "$LOG" 2>&1; then
  exit 0
fi

TAIL="$(tail -n 20 "$LOG" 2>/dev/null | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read())[1:-1])' 2>/dev/null || true)"
python3 - "$TAIL" <<'PY'
import json,sys
tail=sys.argv[1] if len(sys.argv)>1 else ""
print(json.dumps({"hookSpecificOutput":{
  "hookEventName":"PreToolUse",
  "permissionDecision":"deny",
  "permissionDecisionReason":"verify.sh failed - fix errors before committing, then retry. Tail of build/verify-hook.log:\n"+tail
}}))
PY
exit 0
