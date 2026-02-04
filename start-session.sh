#!/bin/bash
# start-claude-session.sh - Start Claude Code with channel registration for monitoring
#
# Usage: start-claude-session.sh --workdir DIR --channel CHANNEL [--prompt TEXT] [--session NAME]
#
# Example (from Lizi):
#   start-claude-session.sh \
#     --workdir /home/matt/bibleai \
#     --channel "discord:channel:1466888482793459813" \
#     --prompt "/implement feature-x"
#
# Example (manual):
#   start-claude-session.sh \
#     --workdir ~/myproject \
#     --channel "telegram:chat:987654" \
#     --session my-task

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults
WORKDIR=""
CHANNEL=""
PROMPT=""
SESSION=""
AUTO_START_MONITOR=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workdir)
            WORKDIR="$2"
            shift 2
            ;;
        --channel)
            CHANNEL="$2"
            shift 2
            ;;
        --prompt)
            PROMPT="$2"
            shift 2
            ;;
        --session)
            SESSION="$2"
            shift 2
            ;;
        --no-auto-monitor)
            AUTO_START_MONITOR=false
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "" >&2
            echo "Usage: $0 --workdir DIR --channel CHANNEL [--prompt TEXT] [--session NAME]" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$WORKDIR" ]; then
    echo "Error: --workdir is required" >&2
    exit 1
fi

if [ -z "$CHANNEL" ]; then
    echo "Error: --channel is required" >&2
    exit 1
fi

if [ ! -d "$WORKDIR" ]; then
    echo "Error: Working directory does not exist: $WORKDIR" >&2
    exit 1
fi

# Generate session name if not provided
if [ -z "$SESSION" ]; then
    SESSION="claude-$(date +%s)"
fi

# Validate session name
if [[ ! "$SESSION" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid session name. Use only alphanumeric characters, underscores, and hyphens." >&2
    exit 1
fi

echo "[Nebo] Starting Claude Code session with monitoring"
echo "[Nebo] Session: $SESSION"
echo "[Nebo] Workdir: $WORKDIR"
echo "[Nebo] Channel: $CHANNEL"
if [ -n "$PROMPT" ]; then
    echo "[Nebo] Prompt: $PROMPT"
fi
echo ""

# Step 1: Register channel in registry
echo "[Nebo] Registering channel..."
"$SCRIPT_DIR/lib/register-session-channel.sh" "$SESSION" "$CHANNEL"

# Step 2: Start monitor daemon if not running
if [ "$AUTO_START_MONITOR" = true ]; then
    STATE_DIR="${NEBO_MONITOR_STATE_DIR:-/tmp/nebo-orchestrator}"
    PID_FILE="$STATE_DIR/nebo-monitor.pid"
    
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "[Nebo] Monitor daemon already running"
    else
        echo "[Nebo] Starting monitor daemon..."
        "$SCRIPT_DIR/nebo-monitor.sh" >/dev/null 2>&1 &
        sleep 2
        if [ -f "$PID_FILE" ]; then
            echo "[Nebo] Monitor daemon started (PID: $(cat "$PID_FILE"))"
        else
            echo "[Nebo] Warning: Monitor daemon may not have started correctly" >&2
        fi
    fi
fi

# Step 3: Create tmux session
echo "[Nebo] Creating tmux session..."
tmux new-session -d -s "$SESSION" -c "$WORKDIR"

# Step 4: Start Claude Code
echo "[Nebo] Launching Claude Code..."
tmux send-keys -t "$SESSION" "claude" C-m

# Wait for initialization
sleep 5

# Check for trust prompt
echo "[Nebo] Checking for trust prompt..."
for i in {1..5}; do
    OUTPUT=$(tmux capture-pane -t "$SESSION" -p 2>/dev/null || echo "")
    if echo "$OUTPUT" | grep -q "Do you trust"; then
        echo "[Nebo] Trust prompt detected, approving..."
        tmux send-keys -t "$SESSION" Enter
        sleep 2
        break
    fi
    sleep 1
done

# Step 5: Send prompt if provided
if [ -n "$PROMPT" ]; then
    echo "[Nebo] Sending prompt..."
    sleep 7  # Extra wait after trust prompt
    tmux send-keys -t "$SESSION" -l -- "$PROMPT"
    sleep 1
    tmux send-keys -t "$SESSION" C-m
    sleep 1
    tmux send-keys -t "$SESSION" C-m
fi

echo ""
echo "[Nebo] ✓ Session started successfully!"
echo ""
echo "Session name: $SESSION"
echo "Channel: $CHANNEL"
echo ""
echo "Commands:"
echo "  Monitor:  tmux attach -t $SESSION"
echo "  Status:   tmux capture-pane -t $SESSION -p"
echo "  Kill:     tmux kill-session -t $SESSION"
echo ""
echo "Approval commands (in Discord/Telegram/WhatsApp):"
echo "  approve $SESSION  - Allow once"
echo "  always $SESSION   - Allow all similar"
echo "  deny $SESSION     - Reject"
echo ""
