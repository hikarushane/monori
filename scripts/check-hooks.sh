#!/usr/bin/env bash
# Regression guard for fa5bb64.
#
# The verify.sh PreToolUse hook's `if` gate ("Bash(git commit *)") MUST live
# INSIDE the hook command object (next to `command`/`timeout`), NOT as a sibling
# of `matcher`. When `if` sits at the matcher level Claude Code does not
# recognize it, so verify.sh (full iOS build + ChapterlyCore tests) fires on
# EVERY Bash command instead of only on `git commit` — an effective lockup.
#
# This check fails loudly if that nesting ever regresses. It is run as Step 0 of
# verify.sh, so every commit re-validates the hook config before the costly build.
#
# Usage: check-hooks.sh [path/to/settings.json]   (defaults to repo .claude/settings.json)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS="${1:-$PROJECT_DIR/.claude/settings.json}"

if [ ! -f "$SETTINGS" ]; then
  echo "check-hooks: $SETTINGS not found — skipping (no repo Claude hooks here)"
  exit 0
fi

python3 - "$SETTINGS" <<'PY'
import json, sys

with open(sys.argv[1]) as f:
    cfg = json.load(f)

pre = cfg.get("hooks", {}).get("PreToolUse", [])
errors = []

# 1) `if` must never be a sibling of `matcher` (the fa5bb64 bug).
for i, entry in enumerate(pre):
    if "if" in entry:
        errors.append(
            f"PreToolUse[{i}]: `if` is a sibling of `matcher` — this is the "
            f"fa5bb64 regression. Move `if` inside the hook command object."
        )

# 2) The verify.sh hook must keep its gate `if` inside the command object.
verify_hooks = [
    h
    for entry in pre
    for h in entry.get("hooks", [])
    if "verify.sh" in h.get("command", "")
]
if not verify_hooks:
    errors.append("verify.sh PreToolUse hook not found in .claude/settings.json.")
else:
    for h in verify_hooks:
        gate = h.get("if")
        if gate != "Bash(git commit *)":
            errors.append(
                "verify.sh hook: expected `if` == 'Bash(git commit *)' inside the "
                f"command object, got {gate!r}."
            )

if errors:
    print("HOOK CONFIG CHECK FAILED (see fa5bb64):")
    for e in errors:
        print("  -", e)
    sys.exit(1)

print("hook config OK — verify.sh gated on `git commit` only")
PY
