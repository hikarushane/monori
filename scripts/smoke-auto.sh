#!/usr/bin/env bash
# Fully automated smoke test driver. Exit codes:
#   0  all steps passed (goal condition met)
#   1  one or more steps failed / build failed / timeout
#   2  not logged in to Patreon (manual login required once)
#   3  configuration error (missing SMOKE_TEST_URL or preflight failure)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SMOKE_DIR="$PROJECT_DIR/build/smoke"
SCHEME="Monori"
PROJECT="Monori.xcodeproj"
BUNDLE_ID="dev.monori.Monori"
PHASE1_TIMEOUT=180
PHASE2_TIMEOUT=90
EXPECTED_STEPS=8
LOG_PREDICATE='subsystem == "dev.monori" AND category == "smoke-diagnostics"'

mkdir -p "$SMOKE_DIR"

# --- Config ---
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/.env"
  set +a
fi
if [ -z "${SMOKE_TEST_URL:-}" ]; then
  echo "ERROR: SMOKE_TEST_URL is not set."
  echo "Add this line to .env (see .env.example):"
  echo "  SMOKE_TEST_URL=https://www.patreon.com/collection/<your-collection-id>"
  exit 3
fi

# --- Preflight (reuses smoke-diagnostics.sh checks) ---
if ! ./scripts/smoke-diagnostics.sh preflight-only; then
  echo "Preflight failed - see build/smoke/preflight-report.md"
  exit 3
fi

BOOTED_UDID=$(xcrun simctl list devices booted -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('state') == 'Booted':
            print(d['udid']); sys.exit(0)
sys.exit(1)
")
DESTINATION="platform=iOS Simulator,id=$BOOTED_UDID"

# --- Build & install (never uninstall/erase: preserves Patreon login) ---
echo "--- Build ---"
if ! xcodebuild build \
    -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" \
    -configuration Debug CODE_SIGNING_ALLOWED=NO \
    > "$SMOKE_DIR/auto-build.log" 2>&1; then
  tail -30 "$SMOKE_DIR/auto-build.log"
  echo "Build failed - full log: $SMOKE_DIR/auto-build.log"
  exit 1
fi

APP_PATH="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings \
  -configuration Debug -destination "$DESTINATION" 2>/dev/null \
  | grep "BUILT_PRODUCTS_DIR" | head -1 | awk '{print $3}')/Monori.app"
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: built app not found at $APP_PATH"
  exit 1
fi
xcrun simctl install "$BOOTED_UDID" "$APP_PATH"
echo "Installed $APP_PATH"

# --- Phase runner ---
run_phase() { # $1=phase-arg $2=timeout-seconds $3=label
  local phase_arg="$1" timeout="$2" label="$3" start waited=0
  start=$(date '+%Y-%m-%d %H:%M:%S')
  xcrun simctl terminate "$BOOTED_UDID" "$BUNDLE_ID" 2>/dev/null || true
  sleep 1
  xcrun simctl launch "$BOOTED_UDID" "$BUNDLE_ID" \
    --smoke-diagnostics "$phase_arg" -SmokeTestURL "$SMOKE_TEST_URL"
  echo "--- $label launched; waiting for autopilot=complete (max ${timeout}s) ---"
  while [ "$waited" -lt "$timeout" ]; do
    sleep 5
    waited=$((waited + 5))
    xcrun simctl spawn "$BOOTED_UDID" log show --predicate "$LOG_PREDICATE" \
      --style compact --start "$start" 2>/dev/null \
      > "$SMOKE_DIR/auto-$label.log" || true
    if grep -q "autopilot=complete" "$SMOKE_DIR/auto-$label.log"; then
      echo "$label complete after ${waited}s"
      return 0
    fi
  done
  echo "$label TIMEOUT after ${timeout}s (no autopilot=complete in log)"
  return 1
}

rm -f "$SMOKE_DIR"/auto-phase1.log "$SMOKE_DIR"/auto-phase2.log

PHASE_FAIL=0
run_phase "--smoke-autopilot" "$PHASE1_TIMEOUT" "phase1" || PHASE_FAIL=1

if [ "$PHASE_FAIL" -eq 0 ] \
   && ! grep -q "step=auth result=fail" "$SMOKE_DIR/auto-phase1.log"; then
  run_phase "--smoke-autopilot-phase2" "$PHASE2_TIMEOUT" "phase2" || PHASE_FAIL=1
fi

# --- Parse results ---
STEPS=$(grep -hoE "step=[a-z_]+ result=(pass|fail)( reason=[^ \"]+)?" \
  "$SMOKE_DIR"/auto-phase*.log 2>/dev/null || true)

{
  echo "# Smoke Auto Report"
  echo ""
  echo "Date: $(date)"
  echo ""
  echo '```'
  echo "$STEPS"
  echo '```'
} > "$SMOKE_DIR/auto-report.md"

echo ""
echo "=== Step results ==="
echo "${STEPS:-<none captured>}"

capture_failure_artifacts() {
  xcrun simctl io "$BOOTED_UDID" screenshot "$SMOKE_DIR/current-screen.png" 2>/dev/null || true
  cat "$SMOKE_DIR"/auto-phase*.log > "$SMOKE_DIR/app.log" 2>/dev/null || true
  echo "Artifacts: $SMOKE_DIR/current-screen.png, $SMOKE_DIR/app.log, $SMOKE_DIR/auto-report.md"
}

if echo "$STEPS" | grep -q "step=auth result=fail reason=not_logged_in"; then
  capture_failure_artifacts
  echo ""
  echo "NOT LOGGED IN: open the Simulator, log into Patreon inside the app once, then re-run."
  exit 2
fi

PASS_COUNT=$(echo "$STEPS" | grep -c "result=pass" || true)
FAIL_COUNT=$(echo "$STEPS" | grep -c "result=fail" || true)

if [ "$PHASE_FAIL" -ne 0 ] || [ "$FAIL_COUNT" -gt 0 ] || [ "$PASS_COUNT" -lt "$EXPECTED_STEPS" ]; then
  capture_failure_artifacts
  echo ""
  echo "FAIL: pass=$PASS_COUNT fail=$FAIL_COUNT expected=$EXPECTED_STEPS"
  exit 1
fi

echo ""
echo "PASS: all $EXPECTED_STEPS steps passed - goal condition met"
exit 0
