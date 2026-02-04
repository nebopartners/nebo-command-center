---
feature_name: "claude-discord MVP"
planned_date: "2026-02-04"
status: "Planned"
design_doc: "docs/plans/2026-02-04-claude-discord-design.md"
---

# TLDR

Implement Discord notification system for Claude Code (and Codex) sessions. CLI wrapper writes per-session hook config with Discord channel ID baked in. When approval needed, hook POSTs to OpenClaw webhook → notification appears in originating Discord channel. User responds via buttons or text (1/2/3). Lizi skill handles approval commands via tmux send-keys.

# Requirements Summary

- Multi-channel Discord routing (notifications go back to originating channel)
- Approval via buttons OR text (1=approve, 2=always, 3=deny)
- CLI wrapper for terminal use + Lizi skill for Discord use
- Support both Claude Code and Codex
- Security: token handling, cleanup, channel ID validation
- Dashboard already exists (Nebo Dev Ops at mg-admin.nebopartners.com)

# Architecture

```
Discord Channel → Lizi Skill → CLI Wrapper → Claude/Codex in tmux
                                    ↓
                         .claude/settings.local.json (hook config)
                                    ↓
                         Hook fires on approval prompt
                                    ↓
                         POST to OpenClaw webhook with channel ID
                                    ↓
                         Notification in Discord channel
                                    ↓
                         User: "1" or clicks Approve button
                                    ↓
                         Lizi skill → handle-approval.sh → tmux send-keys
```

# Implementation Steps

## Phase 1: Core Scripts (CLI Wrapper)

### Step 1.1: Create project structure
```
~/claude-discord/
├── claude-discord.sh          # Main CLI wrapper
├── lib/
│   ├── handle-approval.sh     # Process approve/deny
│   ├── send-notification.sh   # Format & POST to webhook
│   ├── session-cleanup.sh     # Kill session + remove config
│   └── session-status.sh      # Get session state
├── skill/
│   └── claude-discord.skill.md
└── README.md
```

### Step 1.2: Implement claude-discord.sh
- Parse args: --session, --workdir, --prompt, --channel, --agent (claude|codex)
- Validate inputs (channel ID numeric only)
- Write .claude/settings.local.json with webhook config
- chmod 600 on config file
- Create tmux session using OpenClaw socket convention
- Launch claude or codex based on --agent flag
- Send prompt to session

### Step 1.3: Implement lib/handle-approval.sh
- Accept: approve|always|deny + session name
- Validate session exists
- Send appropriate tmux keystrokes:
  - approve: Enter (option 1)
  - always: Down + Enter (option 2)
  - deny: Down + Down + Enter (option 3)

### Step 1.4: Implement lib/send-notification.sh
- Called by Claude Code hook
- Capture tmux pane to extract approval details
- Format message with session name + command
- POST to OpenClaw webhook with channel ID
- Handle errors gracefully

### Step 1.5: Implement lib/session-cleanup.sh
- Kill tmux session
- Remove .claude/settings.local.json
- Log cleanup

### Step 1.6: Implement lib/session-status.sh
- Capture tmux pane output
- Detect status: working, idle, waiting_approval, error
- Support both Claude and Codex prompt patterns
- Output JSON for programmatic use

## Phase 2: Lizi Skill

### Step 2.1: Create claude-discord.skill.md
- Pattern matching for approval commands (1/2/3, approve/always/deny)
- Session spawning via CLI wrapper
- Status commands (sessions, status <name>, kill <name>)
- Extract channel ID from Lizi session context

## Phase 3: Testing

### Step 3.1: Test CLI wrapper standalone
- Start session without --channel (terminal only)
- Verify tmux session created
- Verify claude/codex launches

### Step 3.2: Test with Discord channel
- Start session with --channel
- Verify hook config written with correct channel
- Trigger approval prompt
- Verify notification appears in Discord
- Test all three approval types

### Step 3.3: Test Codex compatibility
- Start session with --agent codex
- Verify approval detection works
- Test keystroke handling

# Files to Create

| File | Purpose |
|------|---------|
| `~/claude-discord/claude-discord.sh` | Main CLI wrapper |
| `~/claude-discord/lib/handle-approval.sh` | Process approvals |
| `~/claude-discord/lib/send-notification.sh` | Webhook notifications |
| `~/claude-discord/lib/session-cleanup.sh` | Cleanup utility |
| `~/claude-discord/lib/session-status.sh` | Status detection |
| `~/claude-discord/skill/claude-discord.skill.md` | Lizi skill definition |
| `~/claude-discord/README.md` | Usage documentation |

# Testing Approach

**Manual tests:**
```bash
# Test 1: CLI without Discord
./claude-discord.sh --session test1 --workdir /tmp/test --prompt "echo hello"

# Test 2: CLI with Discord channel
./claude-discord.sh --session test2 --workdir /tmp/test --prompt "create a file" --channel 123456789

# Test 3: Approval handling
./lib/handle-approval.sh approve test2

# Test 4: Codex
./claude-discord.sh --session test3 --workdir /tmp/test --prompt "fix bug" --agent codex
```

**Verification:**
```bash
# Check session exists
tmux -S "$OPENCLAW_TMUX_SOCKET_DIR/openclaw.sock" has-session -t test1

# Check hook config
cat /tmp/test/.claude/settings.local.json

# Check notification sent (webhook logs)
tail -f ~/.openclaw/logs/webhook.log
```

# Dependencies

- tmux (installed)
- claude CLI (installed)
- codex CLI (needs verification)
- jq (for JSON formatting)
- curl (for webhook POST)
- OpenClaw running with webhook enabled

# Estimated Effort

- Phase 1 (Core Scripts): ~2 hours
- Phase 2 (Lizi Skill): ~1 hour
- Phase 3 (Testing): ~1 hour
- **Total: ~4 hours**

# Open Questions (Resolved)

1. ✅ Channel routing → Bake into hook config (Option A)
2. ✅ Approval UX → Buttons + text fallback
3. ✅ Dashboard → Not MVP (already have Nebo Dev Ops)
4. ✅ Codex support → Add --agent flag, update status detection

# Success Criteria

- [ ] Can spawn Claude Code session from Discord
- [ ] Notification appears in originating Discord channel
- [ ] Can approve via "1" or "approve" text
- [ ] Can approve via button click (if Lizi supports)
- [ ] Session cleanup removes config file
- [ ] Works with Codex (--agent codex)
