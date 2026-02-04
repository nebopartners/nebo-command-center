---
name: nebo-command
description: Monitor and control AI coding agents (Claude Code, Codex) with Discord notifications
metadata: {"openclaw":{"emoji":"⚡","requires":{"bins":["tmux"]}}}
---

# Nebo Command Center

Orchestrate AI coding agents from Discord with approval notifications.

## ⚡ CRITICAL: Handle Approvals First

When user message matches these patterns, IMMEDIATELY run:

| Pattern | Command |
|---------|---------|
| `1` or `approve` or `yes` | `~/nebo-command-center/lib/handle-approval.sh approve <last-session>` |
| `2` or `always` | `~/nebo-command-center/lib/handle-approval.sh always <last-session>` |
| `3` or `deny` or `no` | `~/nebo-command-center/lib/handle-approval.sh deny <last-session>` |
| `approve <session>` | `~/nebo-command-center/lib/handle-approval.sh approve <session>` |
| `always <session>` | `~/nebo-command-center/lib/handle-approval.sh always <session>` |
| `deny <session>` | `~/nebo-command-center/lib/handle-approval.sh deny <session>` |

## Spawning Sessions

When user requests coding work:

```bash
~/nebo-command-center/nebo-session.sh \
  --session "<session-name>" \
  --workdir "<project-dir>" \
  --prompt "<task>" \
  --channel "<discord-channel-id>" \
  --agent claude  # or codex
```

Get Discord channel ID from current session context.

## Status Commands

| User says | Action |
|-----------|--------|
| `sessions` or `status` | List active tmux sessions |
| `status <session>` | Show session output |
| `kill <session>` | Kill session + cleanup |
| `dashboard` | Link to mg-admin.nebopartners.com |

## Session Naming

Generate from task description:
- "fix auth bug" → `fix-auth-bug`
- "add tests for api" → `add-api-tests`

## Dashboard

Real-time web UI: `https://mg-admin.nebopartners.com/?token=<TOKEN>`

Features:
- Live terminal output
- Approval buttons
- Text input for commands
- Multi-session view
