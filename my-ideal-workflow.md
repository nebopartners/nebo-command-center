SYSTEM: Discord-based Multi-Agent Dev Workflow (OpenClaw / ClaudeCode / Codex)

ACTORS:
- User (via Discord)
- OpenClaw Discord Bot (Orchestrator)
- ClaudeCode CLI / Codex CLI (Agents)
- Notion (Feature DB)
- GitHub Repo(s)
- tmux (session manager)

--------------------------------------------------
PHASE 0: FEATURE SOURCE OF TRUTH (Notion)
--------------------------------------------------
Notion DB: Features
Properties:
- name
- repo (optional)
- status
- metadata

Feature Body:
- empty OR
- light notes / highlights OR
- full requirements doc

--------------------------------------------------
PHASE 1: START WORK (Discord)
--------------------------------------------------
User:
- Creates new thread in a forum channel
- Channel is accessible to OpenClaw bot

COMMAND OPTIONS:
1. /start
   Input:
   - Notion feature (name | partial name | URL)
   Behavior:
   - Locate matching Notion feature
   - Pull full Notion context (properties + body)

2. /start-n
   Input:
   - feature name (optional)
   Behavior:
   - Create new Notion feature shell
   - Ask for missing metadata if needed

--------------------------------------------------
PHASE 2: REPO + ENV SETUP
--------------------------------------------------
OpenClaw Bot:
- Determine target repo:
  - Use Notion `repo` property if present
  - Else prompt user to select repo

- Git operations:
  - base_branch = repo.default_branch
  - create new branch from base_branch
  - create git worktree for branch

- Respond in Discord thread with:
  - repo name
  - branch name
  - worktree path
  - GitHub links

- If Notion feature exists:
  - Inject Notion content into thread context

--------------------------------------------------
PHASE 3: REQUIREMENTS / BRAINSTORMING
--------------------------------------------------
User + Bot:
- Iterate in Discord thread
- Clarify scope, constraints, decisions
- No code changes yet

--------------------------------------------------
PHASE 4: PLANNING
--------------------------------------------------
User:
- Runs /plan
- OR /plan-a (auto-approve)

OpenClaw Bot:
- Launch tmux session
- Start ClaudeCode CLI or Codex CLI
- Provide:
  - Notion body (re-pulled)
  - decisions.md (saved during brainstorming)
  - Available chat history (best-effort, subject to compaction)
  - Repo + branch + worktree
  - Planning prompt

Agent:
- Generates implementation plan
- Writes plan.md (or similar) into repo

Blocking behavior:
- Approval prompts: monitor detects → relays to Discord → user responds → resumes agent
- Clarification questions: stretch goal (see workflow-comparison.md §7.5)
  - Fallback: user can tmux attach to interact directly

Completion:
- Commit plan doc
- Push branch to GitHub

Bot Response:
- “Planning complete”
- Link to plan document on GitHub

--------------------------------------------------
PHASE 5: IMPLEMENTATION
--------------------------------------------------
User:
- Runs /implement
- OR /implement-a (auto-approve)

OpenClaw Bot:
- Launch new tmux session
- Start ClaudeCode CLI or Codex CLI
- Provide:
  - plan.md
  - repo + branch + worktree

Agent:
- Implements plan step-by-step
- Commits code as it goes (or at end)

Blocking behavior:
- Same as Phase 4 (approval relay + tmux attach fallback)

--------------------------------------------------
PHASE 6: CODE REVIEW
--------------------------------------------------
Trigger:
- Auto-run after implement OR
- User runs /code-review manually
- OR /code-review-a (auto-approve)


OpenClaw Bot:
- Launch tmux session
- Start ClaudeCode / Codex
- Run code review prompt

Agent Output:
- implementation report (markdown)
- UAT manual test cases list

Post-processing:
- Commit review artifacts
- Push to GitHub

Bot Response in Discord:
- Link to implementation report
- UAT test cases (inline or link)
- Copy/paste git commands:
  - git fetch
  - git checkout <branch>
  - open in IDE
- Instructions for PR → staging/main

--------------------------------------------------
END STATE
--------------------------------------------------
- Feature implemented on isolated branch
- Full audit trail:
  - Notion → Plan → Code → Review
- User performs final local review + PR
