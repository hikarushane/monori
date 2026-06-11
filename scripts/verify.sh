#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

BUILD_DIR="$PROJECT_DIR/build"
RESULT_BUNDLE="$BUILD_DIR/TestResults.xcresult"
LOG_FILE="$BUILD_DIR/xcodebuild.log"

SCHEME="Chapterly"
PROJECT="Chapterly.xcodeproj"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro,OS=latest"

mkdir -p "$BUILD_DIR"
rm -rf "$RESULT_BUNDLE"

echo "=== Step 1: Build ==="
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$LOG_FILE"

echo ""
echo "=== Step 2: Unit tests (ChapterlyCore Swift Package) ==="
cd "$PROJECT_DIR/ChapterlyCore"
swift test 2>&1 | tee -a "$LOG_FILE"
cd "$PROJECT_DIR"

echo ""
echo "=== Verify complete ==="
echo "Results: $RESULT_BUNDLE"
echo "Log:     $LOG_FILE"
