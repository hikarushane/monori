#!/usr/bin/env bash
# Driver B for agent-driven Simulator UI automation: a thin wrapper over
# Facebook idb so that any shell-capable agent (Codex, Claude Code CLI,
# ...) can tap, swipe, and screenshot the booted Simulator without the
# computer-use MCP. All coordinates are DEVICE POINTS, origin top-left.
#
# Read SIMULATOR_PLAYBOOK.md before driving. Hard rules: never interact
# with login / CAPTCHA / Cloudflare / 2FA screens, never type
# credentials, never erase or reset the Simulator.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UI_DIR="$PROJECT_DIR/build/smoke/ui"
BUNDLE_ID="dev.monori.Monori"

# pipx installs idb into ~/.local/bin; agent shells are often non-login
# shells that miss it.
export PATH="$HOME/.local/bin:$PATH"

mkdir -p "$UI_DIR"

usage() {
  cat <<'EOF'
usage: ui-driver.sh <command> [args]

  doctor                             readiness check (exit 0 = ready, 3 = not)
  info                               screen size: points, pixels, scale
  describe                           accessibility tree JSON (frames in points);
                                     also saved to build/smoke/ui/describe-last.json
  tap <x> <y>                        tap at a device point
  swipe <x1> <y1> <x2> <y2> [delta]  swipe between device points (default delta 25)
  back                               back edge-swipe (left edge -> right)
  text <string>                      type into the focused field (NEVER credentials)
  shot <desc>                        screenshot -> build/smoke/ui/step-NN-<desc>.png
EOF
  exit 3
}

fail() { echo "FAIL: $1" >&2; exit 3; }

booted_udid() {
  xcrun simctl list devices booted \
    | sed -n 's/.*(\([0-9A-F][0-9A-F-]*\)) (Booted).*/\1/p' \
    | head -1
}

require_idb() {
  command -v idb >/dev/null 2>&1 \
    || fail "idb not installed. See 'Driver B setup' in SIMULATOR_PLAYBOOK.md."
}

require_target() {
  require_idb
  UDID="$(booted_udid)"
  [ -n "$UDID" ] || fail "No booted Simulator. Ask the user to boot one (never erase devices)."
}

# Prints "<width_points> <height_points> <scale>" for the booted device.
screen_info() {
  idb describe --udid "$UDID" --json | /usr/bin/python3 -c '
import json, sys
d = json.load(sys.stdin)
s = d.get("screen_dimensions") or {}
w = s.get("width") or 0
h = s.get("height") or 0
den = s.get("density") or 1
wp = s.get("width_points") or (round(w / den) if w else 0)
hp = s.get("height_points") or (round(h / den) if h else 0)
print(int(wp), int(hp), den)
'
}

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift

case "$cmd" in
  doctor)
    require_target
    echo "udid: $UDID"
    if xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" >/dev/null 2>&1; then
      echo "app_installed: yes"
    else
      echo "app_installed: no (build and install via Xcode or the smoke scripts first)"
    fi
    idb ui describe-all --udid "$UDID" >/dev/null 2>&1 \
      || fail "idb companion could not talk to the Simulator. Retry once; if it still fails, see 'Driver B setup' in SIMULATOR_PLAYBOOK.md."
    read -r WP HP SCALE <<<"$(screen_info)"
    echo "screen_points: ${WP}x${HP}"
    echo "scale: ${SCALE}"
    echo "OK: driver B ready"
    ;;
  info)
    require_target
    idb describe --udid "$UDID" --json | /usr/bin/python3 -c '
import json, sys
d = json.load(sys.stdin)
s = d.get("screen_dimensions") or {}
w = s.get("width") or 0
h = s.get("height") or 0
den = s.get("density") or 1
wp = s.get("width_points") or (round(w / den) if w else 0)
hp = s.get("height_points") or (round(h / den) if h else 0)
print(f"points: {int(wp)} x {int(hp)}")
print(f"pixels: {w} x {h}")
print(f"scale: {den}")
'
    ;;
  describe)
    require_target
    idb ui describe-all --udid "$UDID" | tee "$UI_DIR/describe-last.json"
    ;;
  tap)
    [ $# -eq 2 ] || usage
    require_target
    idb ui tap --udid "$UDID" "$1" "$2"
    ;;
  swipe)
    [ $# -eq 4 ] || [ $# -eq 5 ] || usage
    require_target
    idb ui swipe --udid "$UDID" --delta "${5:-25}" "$1" "$2" "$3" "$4"
    ;;
  back)
    require_target
    # Live calibration 2026-06-13: idb edge-swipe (x=0,5; delta=1,5,10,20,30)
    # did NOT trigger iOS back navigation on iPhone 17 Pro.  UIScreenEdgePan-
    # GestureRecognizer (used by ReaderView) and SwiftUI NavigationStack both
    # ignore idb's synthetic swipe events — idb sends UIPanGestureRecognizer
    # touches, not true edge-pan touches.
    #
    # CONTEXT-DEPENDENT behaviour:
    #   • NavigationStack screens (Library list, TOC): tapping the native "<"
    #     back button at (20, 79) works reliably.  smoke.readerBookmarkButton
    #     also lives near x=4-48 in the reader top bar, so (20, 79) hits the
    #     bookmark when chrome is visible there — avoid calling `back` with
    #     chrome visible in the reader.
    #   • ReaderView (.fullScreenCover, no native back button): the only
    #     programmatic exit is the left-edge UIScreenEdgePanGestureRecognizer
    #     wired to dismiss().  idb cannot fire it.  Workaround: xcrun simctl
    #     terminate + launch (relaunch resets nav to Library without erasing
    #     Patreon login).  A future smoke.readerDismissButton accessibility
    #     element would let us tap-dismiss from here.
    idb ui tap --udid "$UDID" 20 79
    echo "back: tapped nav-bar back button (20, 79)"
    ;;
  text)
    [ $# -ge 1 ] || usage
    require_target
    idb ui text --udid "$UDID" -- "$*"
    ;;
  shot)
    [ $# -eq 1 ] || usage
    n=$(find "$UI_DIR" -maxdepth 1 -name 'step-*.png' | wc -l | tr -d ' ')
    OUT="$UI_DIR/step-$(printf '%02d' $((n + 1)))-$1.png"
    xcrun simctl io booted screenshot "$OUT" >/dev/null 2>&1 \
      || fail "Could not take a device screenshot (is a Simulator booted?)."
    echo "$OUT"
    ;;
  *)
    usage
    ;;
esac
