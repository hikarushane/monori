#!/usr/bin/env bash
# Proves the run-shared adapter is casing-agnostic: every snake/camel fixture
# pair must produce identical, correct CC output. Skips cleanly until Task 1
# builds run-shared.sh, so it is safe to commit now in Task 0A.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../../.." && pwd)"
RUN="$REPO/.codex/hooks/run-shared.sh"
FX="$DIR/fixtures"
[ -f "$RUN" ] || { echo "SKIP test_casing_matrix (run-shared.sh not built yet)"; exit 0; }
fail=0

check() { # $1=event-base  $2=cc-target+args  $3=expected-substr (empty = none)
  local base="$1" target="$2" want="$3"
  local out_snake="" out_camel=""
  for casing in snake camel; do
    local f="$FX/$base.$casing.json"
    [ -f "$f" ] || { echo "FAIL: missing fixture $f"; fail=1; continue; }
    local input; input="$(sed "s#__REPO__#$REPO#g" "$f")"
    local out; out="$(printf '%s' "$input" | bash "$RUN" $target)"
    if [ -n "$want" ]; then
      echo "$out" | grep -q "$want" || { echo "FAIL: $base.$casing missing '$want'"; fail=1; }
    fi
    eval "out_$casing=\$out"
  done
  [ "$out_snake" = "$out_camel" ] || { echo "FAIL: $base snake/camel output differ"; fail=1; }
}

check sessionstart      "flow-pack/load_context.sh"                 "SessionStart"
check userpromptsubmit  "inject_critical_rules.sh UserPromptSubmit" "Patreon"
check stop              "flow-pack/handoff_update_gate.sh"          ""

[ "$fail" = 0 ] && echo "PASS test_casing_matrix" || exit 1
