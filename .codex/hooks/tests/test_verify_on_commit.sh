#!/usr/bin/env bash
# The commit gate must:
#  (1) run verify on a real `git commit` and DENY when verify fails;
#  (2) ALLOW (exit 0, no deny) on a real `git commit` when verify passes;
#  (3) NOT fire verify on non-commit commands, incl. complex Bash that merely
#      contains the string "git commit" (the fa5bb64 false-positive guard).
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../../.." && pwd)"
GATE="$REPO/.codex/hooks/verify-on-commit.sh"
fail=0
MARK="$REPO/build/codex-hooks/.verify_ran"

call() { # $1 = command string ; env VERIFY_CMD controls mock verify exit
  rm -f "$MARK" 2>/dev/null || true
  printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")" \
    | VERIFY_CMD="$2" bash "$GATE"
}

# Mock that records it ran and returns the given code.
PASS_MOCK="bash -c 'mkdir -p \"$REPO/build/codex-hooks\"; : > \"$MARK\"; exit 0'"
FAIL_MOCK="bash -c 'mkdir -p \"$REPO/build/codex-hooks\"; : > \"$MARK\"; exit 1'"

# (1) real commit + failing verify -> deny
out="$(call 'git commit -m wip' "$FAIL_MOCK")"
echo "$out" | grep -q '"permissionDecision": "deny"' || { echo "FAIL(1): expected deny on failing verify"; fail=1; }
[ -f "$MARK" ] || { echo "FAIL(1): verify did not run on real commit"; fail=1; }

# (2) real commit + passing verify -> allow (no deny)
out="$(call 'git commit -m wip' "$PASS_MOCK")"
echo "$out" | grep -q 'deny' && { echo "FAIL(2): denied despite passing verify"; fail=1; }
[ -f "$MARK" ] || { echo "FAIL(2): verify did not run on real commit"; fail=1; }

# (3a) non-commit command -> verify must NOT run
call 'ls -la' "$PASS_MOCK" >/dev/null
[ -f "$MARK" ] && { echo "FAIL(3a): verify ran on 'ls -la'"; fail=1; }

# (3b) complex Bash that merely mentions git commit in a string -> must NOT run
call 'echo "remember to git commit later"' "$PASS_MOCK" >/dev/null
[ -f "$MARK" ] && { echo "FAIL(3b): verify ran on echoed 'git commit'"; fail=1; }

# (3c) chained real commit (separator) -> MUST run
call 'true && git commit -m wip' "$PASS_MOCK" >/dev/null
[ -f "$MARK" ] || { echo "FAIL(3c): verify did not run on chained real commit"; fail=1; }

rm -f "$MARK" 2>/dev/null || true
[ "$fail" = 0 ] && echo "PASS test_verify_on_commit" || exit 1
