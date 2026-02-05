# NEBO Workflow Comparison

## 1. What Exists Today

```
User runs /plan or /implement or /review in Discord
  → skill fires → start-session.sh → tmux + Claude/Codex
  → monitor polls for approval prompts → relays to Discord
  → user approves/denies → session continues
```

**Has:** Slash commands (`/plan`, `/implement`, `/review`, `/codex-review`, `/systematic-debugging-c` + auto-approve variants), tmux session lifecycle, multi-channel delivery (Discord/Telegram/WhatsApp), web dashboard, security hardening.

**Doesn't have:** Notion integration, git branch/worktree automation, multi-repo support (workdir hardcoded to `/home/matt/bibleai`), structured deliverables between phases, completion detection, post-session reporting, per-step agent selection.

---

## 2. Phase Comparison

| Phase | Desired | Today | Status |
|-------|---------|-------|--------|
| Feature source of truth | Notion DB (optional) OR Ad-hoc | Ad-hoc prompt text | Not built |
| Start work | `/start` → branch + worktree + Notion context | Jump straight to `/plan` | Not built |
| Brainstorming | Chat in Discord thread, no code | OpenClaw conversation works | Works (unstructured) |
| Requirements | `/requirements` → `requirements.md` | No equivalent | Not built |
| Planning | `/plan` reads `requirements.md` → `plan.md`, commit, push, post link | `/plan` exists, generic prompt, no artifacts | Needs prompt rewrite |
| Implementation | `/implement` reads `plan.md` → code, commit, push | `/implement` exists, no plan awareness | Needs prompt rewrite |
| Code Review | `/review` → `review.md` + UAT cases, post PR instructions | `/review` exists, no structured output | Needs prompt rewrite |
| Security Review | `/codex-review` → security-focused review with Codex | `/codex-review` exists, good prompt | Needs workdir fix only |
| Debugging | `/systematic-debugging-c` → 4-phase debugging framework | Exists, good prompt | Needs workdir fix only |
| End state | Isolated branch, full artifact trail, PR-ready | Session just ends in tmux | Not built |

---

## 3. Target Workflow

Each phase is a **self-contained command**. No context aggregation between phases — each reads the previous phase's deliverable from the repo. Only the workspace (repo/branch/worktree) persists.

```
/start <repo> [notion-feature]                         agent: n/a (shell only)
  → creates branch + worktree
  → posts workspace details to thread
  → (optional) fetches Notion body into thread
  Current: not built
  New: skills/start/SKILL.md, lib/git-setup.sh

/start-n <feature-name> [repo]                         agent: n/a (shell only)
  → creates Notion feature + branch + worktree
  Current: not built
  New: skills/start-n/SKILL.md
  Requires: Notion API

brainstorming (conversational, no command)
  → user + bot iterate in Discord thread, no code
  Current: works via OpenClaw conversation

/requirements [additional-context]                     agent: claude (default)
  → agent reads thread history + Notion body
  → produces requirements.md, commits, pushes, posts link
  Current: not built
  New: skills/requirements/SKILL.md
  Note: verify OpenClaw passes thread history to skills

/plan [additional-args]                                agent: claude (default)
  → agent reads requirements.md → plan.md
  → commits, pushes, posts link
  Current: exists — needs prompt rewrite
  Changed: skills/plan/SKILL.md, skills/plan-a/SKILL.md

/implement [additional-args]                           agent: codex (default)
  → agent reads plan.md → implements code
  → commits as it goes, pushes, posts summary
  Current: exists — needs prompt rewrite
  Changed: skills/implement/SKILL.md, skills/implement-a/SKILL.md

/review                                                agent: codex (default)
  → agent reviews branch diff
  → produces review.md + uat-tests.md
  → commits, pushes, posts links + PR instructions
  Current: exists — needs prompt rewrite
  Changed: skills/review/SKILL.md, skills/review-a/SKILL.md

/codex-review [files/dirs]                             agent: codex (always)
  → security + quality focused review
  → structured report with severity levels
  Current: exists — needs workdir fix only

/systematic-debugging-c [bug description]              agent: claude (always)
  → 4-phase debugging (root cause → patterns → hypothesis → fix)
  Current: exists — needs workdir fix only
```

All commands support `-a` suffix for auto-approve mode (e.g., `/plan-a`, `/implement-a`).

**Why not context aggregation?** Focused prompts ("read plan.md") produce better LLM output than dumping 50 messages of history. Each deliverable is committed to git = built-in audit trail. Phase goes wrong? Edit the deliverable, re-run. Inline args (`/plan but prioritize the API first`) handle one-off additions.

---

## 4. Implementation Plan

Timeframes assume AI-assisted development (Claude Code Opus).

| # | Item | Time | Depends On | Notes |
|---|------|------|------------|-------|
| **P0** | | | | |
| 1 | Create `nebo.config.json` + loader | 30 min | — | Replaces hardcoded values across all skills. See config schema below. |
| 2 | Rewrite `/plan` skill prompt | 15 min | #1 | Structured: read requirements.md → plan.md → commit → push → post link |
| 3 | Rewrite `/implement` skill prompt | 15 min | #1 | Structured: read plan.md → implement → commit → push → post summary |
| 4 | Rewrite `/review` skill prompt | 15 min | #1 | Structured: review diff → review.md + uat-tests.md → commit → push → post PR instructions |
| 5 | Fix workdir in `/codex-review` + `/systematic-debugging-c` | 10 min | #1 | Prompts are good — just parameterize workdir |
| **P1** | | | | |
| 6 | New `/requirements` skill | 15 min | #1 | Prompt-only. Verify OpenClaw passes thread context first. |
| 7 | Completion detection in monitor | 1-2 hrs | — | `session-status.sh` already detects idle. Add working→idle transition hook. Currently monitor only watches for approval prompts. |
| 8 | Post-phase hook (`lib/on-complete.sh`) | 1-2 hrs | #7 | Post artifact links to channel. Optional: Notion status update. Skills today have no post-processing — this fills the gap. |
| **P2** | | | | |
| 9 | `lib/git-setup.sh` | 1 hr | — | Branch from default_branch, worktree at `worktree_base/<repo>/<branch>` |
| 10 | `/start` skill | 30 min | #9 | Calls git-setup.sh, posts workspace details. Optional Notion fetch. |
| **P3 (optional)** | | | | |
| 11 | Notion API helper (`lib/notion-api.js`) | 1 hr | — | get-feature, create-feature, update-status. Existing script gets 80% there. |
| 12 | `/start-n` skill | 15 min | #11, #9 | Creates Notion feature + workspace in one command |
| 13 | Wire Notion into post-phase hooks | 15 min | #11, #8 | If enabled, update feature status on completion |

**P0 (~1.5 hrs)** gets the deliverable-based workflow running. **P1 (~3 hrs)** adds automation. **P2 (~1.5 hrs)** adds workspace management. **P3 (~1.5 hrs)** adds Notion.

---

## 5. Configuration

Instead of scattering env vars, use a `nebo.config.json` for all non-secret settings + custom prompts. Secrets stay in env vars.

### `nebo.config.json` schema

```jsonc
{
  // Workspace
  "workdir": "/home/matt/bibleai",
  "worktree_base": "~/worktrees",
  "repo_registry": {                          // optional
    "my-app": "~/projects/my-app",
    "api": "~/projects/api-server"
  },

  // Agent defaults per step (override with --agent flag)
  "agents": {
    "requirements": "claude",
    "plan": "claude",
    "implement": "codex",
    "review": "codex",
    "codex-review": "codex",
    "systematic-debugging": "claude"
  },

  // Notion (optional — omit entire block to disable)
  "notion": {
    "features_db_id": "abc123"
  },

  // Custom prompt overrides (optional — omit to use defaults)
  // Each is a path to a markdown file with the prompt template
  "prompts": {
    "plan": "~/.nebo/prompts/plan.md",
    "implement": "~/.nebo/prompts/implement.md",
    "review": "~/.nebo/prompts/review.md"
  }
}
```

### Env vars (secrets only)

```bash
NOTION_API_KEY=secret_xxx          # only if using Notion
OPENCLAW_WEBHOOK_TOKEN=xxx         # already exists
DASHBOARD_TOKEN=xxx                # already exists
```

Config resolution: `nebo.config.json` in repo root → `~/.nebo/config.json` → env var fallbacks.

---

## 6. Customizability

Single codebase, different workflows. Everything is opt-in.

### Kyle's setup (full pipeline + Notion)

```jsonc
// nebo.config.json
{
  "worktree_base": "~/worktrees",
  "repo_registry": {
    "my-app": "~/projects/my-app",
    "api": "~/projects/api-server"
  },
  "agents": {
    "requirements": "claude",
    "plan": "claude",
    "implement": "codex",
    "review": "codex"
  },
  "notion": { "features_db_id": "abc123" }
}
```
```
/start my-app notion-feature-123    → branch + worktree + Notion context
  (brainstorm in thread)
/requirements                       → requirements.md
/plan                               → plan.md
/implement-a                        → code (auto-approve)
/review                             → review.md + uat-tests.md + PR instructions
```

### Matt's setup (direct commands, single repo)

```jsonc
// nebo.config.json
{
  "workdir": "/home/matt/bibleai",
  "agents": {
    "plan": "claude",
    "implement": "claude",
    "review": "codex"
  }
}
```
```
/plan-a build the new API endpoint  → plan.md
/implement-a                        → code
/codex-review                       → security scan
/review                             → review.md
```

### Mix and match

Every phase is optional and independent:
- **Skip `/start`** → set `workdir` in config, work in a fixed directory
- **Use `/start` without Notion** → just pass a repo name, get branch + worktree without any Notion integration
- **Skip `/requirements`** → write your own or go straight to `/plan` with inline args
- **Skip Notion entirely** → omit the `notion` block from config
- **Change agent per step** → override in `agents` config (e.g., use Claude for everything, or Codex for everything)
- **Custom prompts** → point `prompts.plan` etc. to your own markdown templates
- **Auto-approve any step** → append `-a` to any command
- **Add `/codex-review`** → dedicated security pass, pairs well after `/review`
- **Add `/systematic-debugging-c`** → escape hatch when implementation hits unknown bugs
- **Use dashboard** → real-time multi-session visibility at `localhost:3333`

---

## 7. Known Issues, Required Fixes & Improvements

Findings from viability review against OpenClaw's actual capabilities ([docs](https://docs.openclaw.ai/), [session management](https://docs.openclaw.ai/concepts/session), [Discord integration](https://deepwiki.com/openclaw/openclaw/8.4-discord-integration)).

### 7.1 Thread Session Key Parsing (CRITICAL — all skills broken in threads)

**Problem:** Every skill regex-matches `discord:channel:(\d+)` from the session key. OpenClaw uses **thread IDs** (not parent channel IDs) for Discord thread session keys. When a skill is invoked from a thread, the regex fails and throws `"Could not determine channel from session context"`.

**Fix:** Update session key parsing in all SKILL.md files to handle thread-style keys (e.g., `discord:thread:\d+` or whatever format OpenClaw uses). Also update `send-notification.sh`'s `OPENCLAW_REPLY_TO` handling. This is P0 — nothing else works until this is fixed.

### 7.2 Webhook Thread Delivery (HIGH — needs testing)

**Problem:** The monitor sends approval notifications via webhook with `"to": "channel:<id>"`. When a user starts a session from a thread, notifications need to route back **into that thread**, not the parent channel. The [webhook docs](https://docs.openclaw.ai/automation/webhook) confirm Discord as a channel option but don't explicitly confirm thread-level delivery.

**Fix:** Test whether passing a thread ID as the `to` value in webhook POSTs correctly routes into the thread. Store the full session key (not just `discord:channel:ID`) in the channel registry. This should be tested early — if it doesn't work, the notification architecture needs rethinking.

### 7.3 Workspace Persistence Across Phases (MEDIUM)

**Problem:** When `/start` creates a branch + worktree, subsequent commands (`/plan`, `/implement`, `/review`) need to know which worktree to use. The doc doesn't specify how this state carries across skill invocations within a thread.

**Options:**
- **File-based state (recommended):** `/start` writes workspace config to `/tmp/nebo-orchestrator/workspaces/<session-key>.json`. Subsequent skills read it. More reliable than LLM context surviving compaction.
- **OpenClaw session state:** Rely on the LLM remembering. Risky — OpenClaw auto-compacts when context fills, so long threads lose early messages.
- **Nebo config fallback:** If no workspace file found, fall back to `workdir` from `nebo.config.json` (current behavior). This preserves the "skip `/start`" workflow.

### 7.4 Requirements Context Gathering

**Problem:** `/requirements` needs context from the brainstorming phase, but OpenClaw's chat history is subject to [session compaction](https://docs.openclaw.ai/reference/session-management-compaction) and can't be relied on as a durable source.

**Approach — structured saves during brainstorming:**

During brainstorming, users explicitly save key decisions and requirements:
- `"save ___ as a decision"` → OpenClaw appends to `decisions.md` in the worktree (or directly onto the Notion body)
- `"save your last reply as a requirement"` → same mechanism
- This could be a dedicated skill, an OpenClaw memory-write hook, or instructions baked into the main conversational skill

When `/requirements` runs, it gathers context from **durable sources**:
1. Re-pull Notion body (if a feature was linked via `/start`)
2. Read `decisions.md` (saved during brainstorming)
3. Whatever OpenClaw chat history is still available in session context (best-effort, not relied upon)

The agent then synthesizes these into `requirements.md`, commits, pushes, and posts the link.

**Stretch goal — emoji reaction saves:**
Discord emoji reactions (e.g., heart on a message) trigger a save to `decisions.md`. This requires either:
- An OpenClaw reaction event hook (if supported)
- A custom Discord bot listener alongside OpenClaw
- Feasibility unknown — depends on OpenClaw exposing Discord reaction events to skills

### 7.5 Agent Question Relay (STRETCH — significantly harder than approvals)

**Problem:** The ideal workflow envisions the agent asking clarification questions that get relayed to Discord and answered. The current monitor only detects **approval prompts** (regex patterns like "Do you want", "y/n/always"). It does NOT detect:
- Claude Code asking a clarifying question
- Generic `AskUserQuestion`-style prompts
- Free-text input requests

**Why it's hard:**
- Detecting arbitrary questions in tmux output (fragile regex vs. approval prompts which have known patterns)
- Response flow is different — approvals use keystroke navigation (Down, Enter), but free-text requires typing via `tmux send-keys -l`
- Handling the case where the agent continues before the user responds
- Timeout and retry logic

**Recommendation:** Keep this as a stretch goal (P4). The current approval relay handles the 80% case. For the remaining 20%, users can `tmux attach` to interact directly.
