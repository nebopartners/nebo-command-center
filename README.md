# Nebo Command Center ⚡

Monitor and control AI coding agents (Claude Code, Codex) from Discord with real-time approval notifications.

## Features

- **Multi-agent support** - Works with Claude Code and OpenAI Codex
- **Discord notifications** - Approval requests route to originating channel
- **Real-time dashboard** - Web UI at `mg-admin.nebopartners.com`
- **Text + button approvals** - Type `1`/`2`/`3` or click buttons
- **Multi-session** - Run multiple agents in parallel across projects

## Quick Start

### Dashboard

```bash
cd dashboard
npm install
node tmux-dashboard.js
```

Access at `http://localhost:3333/?token=YOUR_TOKEN`

### Spawn a Session

```bash
./nebo-session.sh \
  --session my-task \
  --workdir ~/myproject \
  --prompt "Fix the bug in api.py" \
  --channel 123456789  # Discord channel ID (optional)
```

### Approve from Discord

When an agent needs approval, you'll get a notification:

```
🔒 my-task needs approval
Bash(npm test)

Reply: 1 approve · 2 always · 3 deny
```

Respond with `1`, `2`, `3` or `approve`/`always`/`deny`.

### Approve from Dashboard

Click the approval buttons or type in the input field.

## Architecture

```
Discord Channel → Lizi Skill → CLI Wrapper → Agent in tmux
                                    ↓
                         Hook config (channel baked in)
                                    ↓
                         Approval prompt detected
                                    ↓
                         Notification → Discord
                                    ↓
                         User approves → tmux send-keys
```

## Project Structure

```
nebo-command-center/
├── dashboard/              # Real-time web UI
│   ├── tmux-dashboard.js   # Express + Socket.IO server
│   └── public/index.html   # Frontend
├── lib/
│   ├── handle-approval.sh  # Process approve/deny commands
│   ├── send-notification.sh # POST to webhook
│   ├── session-status.sh   # Detect agent status
│   └── session-cleanup.sh  # Kill session + cleanup
├── skill/
│   └── nebo-command.skill.md # Lizi/OpenClaw skill
├── nebo-session.sh         # Main CLI wrapper
└── docs/
    └── plans/              # Design & implementation docs
```

## Requirements

- tmux
- Node.js (for dashboard)
- Claude Code CLI (`claude`) and/or Codex CLI (`codex`)
- OpenClaw/Lizi (for Discord integration)

## Configuration

### Environment Variables

```bash
OPENCLAW_WEBHOOK_TOKEN     # Auth token for webhook
OPENCLAW_TMUX_SOCKET_DIR   # Socket directory (default: /tmp/openclaw-tmux-sockets)
```

### Dashboard Token

The dashboard reads the token from `~/.openclaw/openclaw.json` → `hooks.token`

Or set `DASHBOARD_TOKEN` environment variable.

## Commands

| Command | Description |
|---------|-------------|
| `./nebo-session.sh --help` | Show usage |
| `tmux attach -t <session>` | Watch agent live |
| `./lib/handle-approval.sh approve <session>` | Approve manually |
| `./lib/session-status.sh <session> --json` | Get status |

## Cloudflare Tunnel (Production)

Dashboard is exposed via Cloudflare Tunnel:

- **URL:** `https://mg-admin.nebopartners.com`
- **Tunnel:** `maverick`
- **Service:** `nebo-dashboard.service`

## License

MIT

---

*Inspired by [claude-code-wingman](https://github.com/yossiovadia/claude-code-wingman) by Yossi Ovadia*
