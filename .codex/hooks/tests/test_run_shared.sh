#!/usr/bin/env bash
# Verifies run-shared.sh (a) normalizes camelCase keys to snake_case and
# (b) execs the target CC script, producing identical output to calling the
# CC script directly with already-normalized input (golden parity).
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../../.." && pwd)"
RUN="$REPO/.codex/hooks/run-shared.sh"
CC="$REPO/.claude/hooks/inject_critical_rules.sh"
fail=0

# (a) camelCase stdin must be normalized and still produce the rules payload.
out_camel="$(printf '{"hookEventName":"UserPromptSubmit","sessionId":"x"}' | bash "$RUN" inject_critical_rules.sh UserPromptSubmit)"
echo "$out_camel" | grep -q 'additionalContext' || { echo "FAIL: no additionalContext from camelCase input"; fail=1; }
echo "$out_camel" | grep -q 'Patreon' || { echo "FAIL: critical rules text missing"; fail=1; }

# (b) golden parity: run-shared output == direct CC script output for same logical input.
out_direct="$(printf '{"session_id":"x"}' | bash "$CC" UserPromptSubmit)"
[ "$out_camel" = "$out_direct" ] || { echo "FAIL: run-shared output != direct CC output"; echo "  via-adapter: $out_camel"; echo "  direct:      $out_direct"; fail=1; }

[ "$fail" = 0 ] && echo "PASS test_run_shared" || exit 1
