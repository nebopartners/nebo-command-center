# Nebo Command Center - Library Scripts

Helper scripts for session management and approval handling.

## Scripts

| Script | Purpose |
|--------|---------|
| `handle-approval.sh` | Process approve/deny/always commands |
| `approval-respond.sh` | Send keystrokes to tmux session |
| `send-notification.sh` | POST approval requests to webhook |
| `session-status.sh` | Detect session status (working/idle/waiting) |
| `session-send.sh` | Send text to a session |
| `register-session-channel.sh` | Register session→channel mapping |

## Usage

```bash
# Approve a session
./handle-approval.sh approve my-session

# Get session status
./session-status.sh my-session --json

# Send notification
./send-notification.sh my-session 123456789
```
