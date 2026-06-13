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
BUNDLE_ID="dev.chapterly.Chapterly"

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
    read -r WP HP SCALE <<<"$(screen_info)"
    MIDY=$(( HP / 2 ))
    idb ui swipe --udid "$UDID" --delta 20 0 "$MIDY" 260 "$MIDY"
    echo "back-swipe issued (0,$MIDY -> 260,$MIDY)"
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
