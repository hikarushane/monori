#!/bin/bash
set -euo pipefail

# Design guard — Uguisu Zen regression check.
# Greps App-owned Swift and CSS for banned visual tokens.
# Exit 0 = clean; exit 1 = violations found.

cd "$(dirname "$0")/.."

VIOLATIONS=0

banner() { printf '\n=== %s ===\n' "$1"; }

check_swift() {
  local label="$1" pattern="$2"
  local hits
  hits=$(grep -rn --include="*.swift" -E "$pattern" App/ 2>/dev/null \
    | grep -v '//.*guard\|//.*ban\|//.*test\|\.systemBackground' || true)
  if [ -n "$hits" ]; then
    echo "FAIL: $label"
    echo "$hits"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
}

check_css() {
  local label="$1" pattern="$2"
  local hits
  hits=$(grep -rn --include="*.css" -E "$pattern" \
    MonoriCore/Sources/MonoriCore/Assets/ 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "FAIL: $label"
    echo "$hits"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
}

banner "Swift: banned surface tokens"
check_swift "Material / blur / vibrancy" \
  '\.ultraThinMaterial|\.thinMaterial|\.thickMaterial|\.regularMaterial|\.bar\b|BackdropBlurView|UIVisualEffectView'
check_swift "secondarySystemFill" '\.secondarySystemFill'
check_swift "Capsule shape" 'Capsule\(\)'
check_swift "Color.accentColor (unauthorized)" 'Color\.accentColor'
check_swift "Native Menu (use UguisuMenuContainer)" '\bMenu\s*\{'

banner "Swift: banned fonts"
check_swift "SF Pro / system font as design base" \
  '"SF Pro"|"SFPro"|\.systemFont\('

banner "Swift: unauthorized green"
check_swift "Color.green outside MonoriDesignSystem" \
  'Color\.green\b'

banner "CSS: banned fonts"
check_css "Georgia in reader CSS" 'Georgia'
check_css "SF Pro in reader CSS" 'SF Pro|-apple-system'
check_css "system sans-serif as primary" 'sans-serif\s*!'

banner "CSS: old colors"
check_css "Old background #faf8f5" '#faf8f5'
check_css "Old dark text #e8e6e3" '#e8e6e3'

banner "CSS: old sizing"
check_css "Old max-width 42em" '42em'
check_css "Old default line-height 1.75" 'line-height,\s*1\.75'

if [ "$VIOLATIONS" -eq 0 ]; then
  echo ""
  echo "Design guard: PASS (no banned tokens found)"
  exit 0
else
  echo ""
  echo "Design guard: FAIL ($VIOLATIONS violation(s))"
  exit 1
fi
