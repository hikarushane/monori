#!/usr/bin/env bash
# Codex UserPromptSubmit must re-inject the Chapterly critical rules every turn,
# identical to the CC hook.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../../.." && pwd)"
fail=0

out="$(printf '{"prompt":"hi","sessionId":"s1"}' | bash "$REPO/.codex/hooks/run-shared.sh" inject_critical_rules.sh UserPromptSubmit)"
echo "$out" | grep -q '"hookEventName": "UserPromptSubmit"' || { echo "FAIL: wrong hookEventName"; fail=1; }
echo "$out" | grep -q 'Patreon' || { echo "FAIL: rules not injected"; fail=1; }

direct="$(printf '{"session_id":"s1"}' | bash "$REPO/.claude/hooks/inject_critical_rules.sh" UserPromptSubmit)"
[ "$out" = "$direct" ] || { echo "FAIL: UserPromptSubmit parity mismatch"; fail=1; }

[ "$fail" = 0 ] && echo "PASS test_userpromptsubmit" || exit 1
