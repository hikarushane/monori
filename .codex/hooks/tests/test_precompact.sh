#!/usr/bin/env bash
# The PreCompact adapter must emit the same well-formed rules payload as CC.
# Whether Codex *honors* PreCompact additionalContext is verified live (Task 10);
# functional parity is guaranteed by the UserPromptSubmit re-injection.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../../.." && pwd)"
fail=0

out="$(printf '{"trigger":"auto","sessionId":"s1"}' | bash "$REPO/.codex/hooks/run-shared.sh" inject_critical_rules.sh PreCompact)"
echo "$out" | grep -q '"hookEventName": "PreCompact"' || { echo "FAIL: wrong hookEventName"; fail=1; }
echo "$out" | grep -q 'Patreon' || { echo "FAIL: rules not injected"; fail=1; }

direct="$(printf '{}' | bash "$REPO/.claude/hooks/inject_critical_rules.sh" PreCompact)"
[ "$out" = "$direct" ] || { echo "FAIL: PreCompact parity mismatch"; fail=1; }

[ "$fail" = 0 ] && echo "PASS test_precompact" || exit 1
