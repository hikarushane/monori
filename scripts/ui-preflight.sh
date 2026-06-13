#!/usr/bin/env bash
# Preflight for agent-driven Simulator UI automation (computer-use MCP or
# the idb driver, scripts/ui-driver.sh). Read-only with respect to
# Simulator state: never boots, erases, installs, or launches anything.
# Safe to run at any time.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UI_DIR="$PROJECT_DIR/build/smoke/ui"
BUNDLE_ID="dev.chapterly.Chapterly"

# pipx installs idb into ~/.local/bin; agent shells are often non-login
# shells that miss it.
export PATH="$HOME/.local/bin:$PATH"

mkdir -p "$UI_DIR"
REPORT="$UI_DIR/preflight.txt"
: > "$REPORT"

log() { echo "$*" | tee -a "$REPORT"; }
fail() { log "FAIL: $1"; exit 3; }

command -v xcrun >/dev/null 2>&1 || fail "xcrun not found. Install Xcode command line tools."

BOOTED_LINE="$(xcrun simctl list devices | grep -m1 '(Booted)' || true)"
if [ -z "$BOOTED_LINE" ]; then
  fail "No booted Simulator. Ask the user, or run: open -a Simulator (never erase devices)."
fi
log "device: ${BOOTED_LINE#"${BOOTED_LINE%%[![:space:]]*}"}"
log "bundle_id: $BUNDLE_ID"

if xcrun simctl get_app_container booted "$BUNDLE_ID" >/dev/null 2>&1; then
  log "app_installed: yes"
else
  log "app_installed: no (build and install via Xcode or the smoke scripts first)"
fi

if command -v idb >/dev/null 2>&1; then
  log "driver_b_idb: installed"
else
  log "driver_b_idb: not installed (see 'Driver B setup' in SIMULATOR_PLAYBOOK.md)"
fi

if xcrun simctl io booted screenshot "$UI_DIR/baseline.png" >/dev/null 2>&1; then
  log "baseline: build/smoke/ui/baseline.png"
else
  fail "Could not take a device screenshot."
fi

log "OK: ready for UI driving. Read SIMULATOR_PLAYBOOK.md before acting."
