# AGENTS.md

Codex adapter for Monori. Keep this file short on purpose: the canonical
project instructions live in `CLAUDE.md`, and Codex should not drift by
maintaining a second full copy.

## Canonical Instructions

- Read and follow `CLAUDE.md` for project rules. When it says "Claude",
  treat that as "Codex/agent" unless the rule is explicitly about a
  Claude-only tool.
- Read `.claude/hooks/critical_rules.txt` as the compact always-on rule
  set. These are the rules Claude Code and the Codex hook adapter reinject
  during a session.
- If `HANDOFF.md` or `MEMORY.md` exist, load them before substantial work
  and update them when the task changes durable project state.

## Simulator UI

- Before driving the iOS Simulator, read `SIMULATOR_PLAYBOOK.md`.
- Prefer driver B: `./scripts/ui-preflight.sh`, then
  `./scripts/ui-driver.sh doctor`, then `./scripts/ui-driver.sh`.
- Patreon login, CAPTCHA, Cloudflare checks, 2FA, email verification, and
  payment/App Store sheets are always manual user steps.
- Never erase/reset the Simulator or delete the app during Patreon smoke
  work unless the user explicitly asks.

## Hook Synchronization

- `.claude/settings.json` remains the source of truth for project hook
  behavior.
- `.codex/hooks.json` must call `scripts/codex-hook-adapter.py`, which
  reads `.claude/settings.json` at runtime. Do not duplicate Claude hook
  commands into Codex config.
- Codex currently mirrors the Claude project hooks used here:
  `PreToolUse`, `SessionStart`, `Stop`, `UserPromptSubmit`, and
  `PreCompact`. If Claude hook events change, update only the Codex event
  registrations; keep hook command logic in `.claude/settings.json`.
- `.claude/settings.local.json` is a Claude-local permission allowlist. Do
  not treat those allow entries as Codex safety policy; Codex permissions
  are governed by the app/session, while project behavior remains governed
  by `CLAUDE.md` and this adapter.
- `.claude/settings.json.bak.*` files are backups, not canonical sources.
- As of this migration there are no repo-local `.claude/commands`,
  `.claude/agents`, or Claude MCP config files to mirror. If any are added,
  decide whether Codex needs an equivalent and update this file plus
  `./scripts/check-hooks.sh`; the hook check fails fast when those surfaces
  appear without an explicit migration decision.
- After changing `.claude/settings.json`, `.codex/hooks.json`,
  `AGENTS.md`, or hook scripts, run `./scripts/check-hooks.sh`.
