#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

BUILD_DIR="$PROJECT_DIR/build"
RESULT_BUNDLE="$BUILD_DIR/TestResults.xcresult"
LOG_FILE="$BUILD_DIR/xcodebuild.log"
SWIFT_TEST_LOG="$BUILD_DIR/swift-test.log"

SCHEME="Monori"
PROJECT="Monori.xcodeproj"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro,OS=latest"

mkdir -p "$BUILD_DIR"
rm -rf "$RESULT_BUNDLE"

echo "=== Step 0: Hook config regression check (guards fa5bb64) ==="
"$PROJECT_DIR/scripts/check-hooks.sh"

echo ""
echo "=== Step 0.5: Design guard (Uguisu Zen regression check) ==="
"$PROJECT_DIR/scripts/design-guard.sh"

echo ""
echo "=== Step 1: Ensure Xcode project (XcodeGen) ==="
if [ ! -d "$PROJECT" ]; then
  echo "$PROJECT missing — generating with xcodegen"
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "ERROR: xcodegen not installed. Run: brew install xcodegen" | tee "$LOG_FILE"
    exit 1
  fi
  xcodegen generate
fi

echo "=== Step 2: Build ==="
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$LOG_FILE"

echo ""
echo "=== Step 3: Unit tests (MonoriCore Swift Package) ==="
cd "$PROJECT_DIR/MonoriCore"
# SWBBuildService (Xcode's long-running build daemon) keeps .build/build.db open;
# swift test can exit non-zero from a transient I/O collision even when all tests pass.
# Capture the exit code without triggering set -e, then only hard-fail on real failures.
set +e
swift test 2>&1 | tee "$SWIFT_TEST_LOG" | tee -a "$LOG_FILE"
SWIFT_EXIT=${PIPESTATUS[0]}
set -e
if [ "$SWIFT_EXIT" -ne 0 ]; then
  # A crashed test run (fatalError / signal) never prints the "with N failures"
  # summary line, so also match assertion-failure lines and crash markers —
  # otherwise a real failure gets misclassified as the transient build.db race.
  if grep -qE "with [1-9][0-9]* failures?|error: -\[|Fatal error:|exited with unexpected signal" "$SWIFT_TEST_LOG"; then
    echo "ERROR: MonoriCore tests have real failures (see $LOG_FILE)." >&2
    exit 1
  fi
  # Regression guard (2026-07-12 incident): a test-target COMPILE error (e.g.
  # "error: cannot find 'AutoCheckScheduler' in scope") exits non-zero without a
  # "with N failures" line, so the race tolerance below used to swallow it and
  # verify.sh reported a false green. Hard-fail on any error: line that is not
  # the known transient build.db I/O collision.
  NON_RACE_ERRORS=$(grep -E "error:" "$SWIFT_TEST_LOG" | grep -vE "build\.db|database is locked|disk I/O error" || true)
  if [ -n "$NON_RACE_ERRORS" ]; then
    echo "ERROR: swift test exited $SWIFT_EXIT with build/compile errors (not the transient build.db race):" >&2
    echo "$NON_RACE_ERRORS" | head -5 >&2
    exit 1
  fi
  echo "(swift test exit $SWIFT_EXIT — transient build.db race; tests passed, continuing)" | tee -a "$LOG_FILE"
fi
cd "$PROJECT_DIR"

echo ""
echo "=== Verify complete ==="
echo "Results: $RESULT_BUNDLE"
echo "Log:     $LOG_FILE"
