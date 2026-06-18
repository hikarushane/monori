#!/usr/bin/env bash
# Codex SessionStart must inject the same project handoff/memory context as the
# CC SessionStart hook. Parity = adapter output equals direct CC script output.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../../.." && pwd)"
fail=0

out="$(printf '{"cwd":"%s","trigger":"startup"}' "$REPO" | bash "$REPO/.codex/hooks/run-shared.sh" flow-pack/load_context.sh)"
echo "$out" | grep -q '"hookEventName": "SessionStart"' || { echo "FAIL: missing SessionStart hookEventName"; fail=1; }
echo "$out" | grep -q 'HANDOFF' || { echo "FAIL: HANDOFF.md content not injected"; fail=1; }

direct="$(printf '{"cwd":"%s"}' "$REPO" | bash "$REPO/.claude/hooks/flow-pack/load_context.sh")"
[ "$out" = "$direct" ] || { echo "FAIL: SessionStart parity mismatch"; fail=1; }

[ "$fail" = 0 ] && echo "PASS test_sessionstart" || exit 1
