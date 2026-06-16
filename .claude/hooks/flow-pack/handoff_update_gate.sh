#!/usr/bin/env bash
# Stop hook: advisory, non-blocking reminder to update HANDOFF.md/MEMORY.md
# when real code work happened this session but HANDOFF.md is stale.
# One nudge per session_id. No-op when HANDOFF.md absent or no work detected.
set -uo pipefail

INPUT="$(cat)"
read_field() { printf '%s' "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('$1',''))" 2>/dev/null || true; }
CWD="$(read_field cwd)"; SID="$(read_field session_id)"
[ -n "$CWD" ] && [ -d "$CWD" ] || exit 0
[ -f "$CWD/HANDOFF.md" ] || exit 0                      # project not using the flow -> silent
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0

MARK="$CWD/.git/.flow_nudged_${SID:-nosid}"
[ -f "$MARK" ] && exit 0                                 # already nudged this session

# Work detection: uncommitted changes to non-doc (code) files this session.
DIRTY="$(git -C "$CWD" status --porcelain 2>/dev/null | grep -Ev '\.(md|markdown|txt)$' || true)"
[ -n "$DIRTY" ] || exit 0                                # no uncommitted code work -> silent

: > "$MARK" 2>/dev/null || true
MSG="⚠ flow-pack：本 session 有程式碼變更但 HANDOFF.md 似乎未更新。完成任務請更新 HANDOFF.md（進度）+ MEMORY.md（持久決策），或召喚 agent-handoff（/handoff）。"
python3 - "$MSG" <<'PY'
import json, sys
print(json.dumps({"systemMessage": sys.argv[1]}, ensure_ascii=False))
PY
