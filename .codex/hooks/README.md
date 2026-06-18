# Codex hook adapters

These adapters give the Codex harness parity with the Claude Code repo hooks in
`.claude/`. Each adapter normalizes Codex stdin and execs the existing,
already-tested `.claude/hooks/*` script, so behavior cannot drift from CC.

## Event support notes (verified from the Codex binary's embedded hook schema)

| Event | Fires | Injects `additionalContext` | Notes |
|-------|-------|-----------------------------|-------|
| PreToolUse | yes | yes (also `permissionDecision: deny`) | commit gate + graphify reminders |
| SessionStart | yes | yes | loads HANDOFF.md / MEMORY.md |
| UserPromptSubmit | yes | yes | re-injects critical rules every turn |
| PreCompact | yes | **no wire** | wired best-effort; rules still survive compaction via the UserPromptSubmit re-injection on the next turn |
| Stop | yes | no wire, but `systemMessage` yes | handoff nudge (uses `systemMessage` only) |

## Testing

Deterministic fixture-replay + golden-parity tests live in
`.codex/hooks/tests/` and run headless from `scripts/verify.sh`
(via `scripts/test-codex-hooks.sh`). Live firing is confirmed with
`codex exec` (see the plan, Task 10).
