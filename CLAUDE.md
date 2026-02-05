# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NEBO Command Center (Network of Error-fixing Bots and Operations) is a Bash/Node.js system that manages Claude Code and Codex CLI sessions via multi-channel chat commands (Discord, Telegram, WhatsApp). Users invoke slash commands in Discord, which start AI coding sessions in tmux, with approval prompts and results routed back to the originating channel.

## Architecture

### Execution Flow

```
Discord slash command → OpenClaw skill → start-session.sh → tmux session (claude/codex)
                                                          → registers session→channel mapping
                                                          → starts nebo-monitor.sh daemon
nebo-monitor.sh polls tmux sessions → detects approval prompts → sends notification to channel
User responds (approve/deny/always) → handle-approval.sh → sends keys to tmux → agent continues
```

### Key Entry Points

- **`start-session.sh`** — Primary entry point. Creates tmux session, launches claude/codex, registers channel mapping, starts monitor daemon. Args: `--workdir`, `--channel`, `--prompt`, `--auto-approve`, `--agent claude|codex`, `--session`.
- **`nebo-monitor.sh`** — Background daemon polling all tmux sessions for approval prompts. Sends notifications via OpenClaw webhook. Args: `--poll-interval`, `--reminder-interval`.
- **`nebo-session.sh`** — Legacy wrapper, prefer `start-session.sh`.

### Helper Scripts (`lib/`)

| Script | Purpose |
|---|---|
| `register-session-channel.sh` | Maps session name → channel context in JSON registry |
| `send-notification.sh` | Posts messages to OpenClaw webhook |
| `handle-approval.sh` | Processes approve/deny/always commands |
| `approval-respond.sh` | Sends keystrokes to tmux session |
| `session-status.sh` | Detects session state (waiting/working/error/idle) via tmux output patterns |
| `session-send.sh` | Sends arbitrary text to a session |
| `session-cleanup.sh` | Cleans up finished sessions |

### OpenClaw Skills (`skills/`)

Each skill is a `SKILL.md` file with YAML frontmatter (`user-invocable: true`) that Discord registers as a slash command. Skills call `start-session.sh` with the channel context extracted from the OpenClaw session.

- `plan` / `plan-a` — Planning (manual / auto-approve)
- `implement` / `implement-a` — Implementation (manual / auto-approve)
- `review` / `review-a` — Review (manual / auto-approve)
- `codex-review` — Security review via Codex CLI
- `systematic-debugging-c` — Debugging framework

Skills contain hardcoded `--workdir` paths that must be updated per deployment.

### Web Dashboard (`dashboard/`)

Express.js + Socket.IO app showing real-time session status. Requires auth token (from `DASHBOARD_TOKEN` env var or `~/.openclaw/openclaw.json`).

```bash
cd dashboard && npm install && npm start
```

### State & Runtime Data

All stored in `/tmp/nebo-orchestrator/` (permissions: 700):
- `channel-registry.json` — Session → channel mappings
- `notify-state/` — Deduplication state files (prevents duplicate notifications)
- `nebo-monitor.pid` / `nebo-monitor.log` — Monitor daemon PID and logs

## System Dependencies

- `tmux` — Session isolation and output capture (required)
- `jq` — JSON parsing (required)
- `bash` 4.0+ — Associative arrays (required)
- `curl` — Webhook notifications (required)
- `claude` CLI — Claude Code (required for claude agent)
- `codex` CLI — Codex (optional, for codex agent)
- `node` — Only needed for dashboard

## Key Commands

```bash
# Start a session
./start-session.sh --workdir ~/project --channel "discord:channel:ID" --prompt "task"

# Manage sessions
tmux list-sessions
tmux attach -t claude-<timestamp>
tmux capture-pane -t claude-<timestamp> -p

# Approval handling
./lib/handle-approval.sh approve|deny|always <session-name>

# Monitor logs
tail -f /tmp/nebo-orchestrator/nebo-monitor.log

# Dashboard
cd dashboard && npm install && DASHBOARD_TOKEN=<token> node tmux-dashboard.js
```

## Security Considerations

The codebase has been security-audited (see `docs/security-audit-2026-02-04.md` and `docs/SECURITY_FIXES.md`). Key patterns to maintain:

- **Session names** are validated with `^[a-zA-Z0-9_-]+$` to prevent injection
- **`tmux send-keys -l`** (literal mode) is used to prevent command injection via prompts
- **`execFileSync`** (not `execSync`) is used in the dashboard to avoid shell injection
- **Webhook tokens** are passed via file/header, never as command-line arguments
- **State directory** permissions are enforced at 700, registry files at 600

## No Build/Test System

This is a Bash script project with no compilation step and no automated test suite. Testing is done manually by invoking skills from Discord and monitoring logs.
