#!/usr/bin/env bash
# SessionStart hook: force-load project handoff/memory/instructions into context.
# Reads stdin JSON {cwd,...}; emits hookSpecificOutput.additionalContext if any
# of HANDOFF.md / MEMORY.md exist in the project root. No-op otherwise.
# (CLAUDE.md intentionally excluded — Claude Code loads it natively at session
#  start; re-injecting it here only duplicates. Mid-session drift is handled by
#  the UserPromptSubmit + PreCompact hooks in .claude/hooks/inject_critical_rules.sh.)
set -uo pipefail

INPUT="$(cat)"
CWD="$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null || true)"
[ -n "$CWD" ] && [ -d "$CWD" ] || exit 0

FOUND=0
SECTIONS=""
for f in HANDOFF.md MEMORY.md; do
  if [ -f "$CWD/$f" ]; then
    FOUND=1
    SECTIONS="${SECTIONS}

===== $f =====
$(cat "$CWD/$f")"
  fi
done
if [ "$FOUND" -eq 0 ]; then
  # Neither present: warn (non-blocking), inject nothing.
  python3 - <<'PY'
import json
print(json.dumps({"systemMessage":
  "⚠ flow-pack：此專案缺少 HANDOFF.md / MEMORY.md，未載入交接脈絡。"
  "需要時用 /handoff 產生 HANDOFF.md+MEMORY.md。"},
  ensure_ascii=False))
PY
  exit 0
fi

export FP_SECTIONS="本 session 必讀並遵守以下專案交接與規範檔（flow-pack SessionStart 強制載入）：${SECTIONS}"
python3 - <<'PY'
import json, os
ctx = os.environ.get("FP_SECTIONS", "")
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ctx
}}, ensure_ascii=False))
PY
