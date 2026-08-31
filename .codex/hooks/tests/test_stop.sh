#!/usr/bin/env bash
# Codex Stop must nudge (systemMessage) when there is uncommitted *code* work and
# HANDOFF.md exists, and stay silent otherwise — identical to the CC hook.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../../.." && pwd)"
fail=0
SID="codextest-$$-$RANDOM"
MARK="$REPO/.git/.flow_nudged_${SID}"
rm -f "$MARK" 2>/dev/null || true

run() { printf '{"cwd":"%s","sessionId":"%s"}' "$REPO" "$SID" | bash "$REPO/.codex/hooks/run-shared.sh" flow-pack/handoff_update_gate.sh; }

# Create a throwaway uncommitted CODE change so the work-detector trips.
TMP="$REPO/.codex/hooks/.stoptest_scratch.swift"
echo "// scratch $SID" > "$TMP"

out="$(run)"
echo "$out" | grep -q 'systemMessage' || { echo "FAIL: expected systemMessage nudge with dirty code"; fail=1; }

# Second call in same session must be silent (one-nudge-per-session marker).
out2="$(run)"
[ -z "$out2" ] && echo "ok: silent on 2nd call" || { echo "FAIL: nudged twice in one session"; fail=1; }

# Cleanup
rm -f "$TMP" "$MARK" 2>/dev/null || true

[ "$fail" = 0 ] && echo "PASS test_stop" || { rm -f "$TMP" "$MARK" 2>/dev/null; exit 1; }
