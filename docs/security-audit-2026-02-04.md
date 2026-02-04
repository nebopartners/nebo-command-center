# Nebo Command Center Security Audit Report
**Date:** 2026-02-04
**Scope:** Full repository (`nebo-command-center`)
**Method:** Manual review of bash scripts, Node.js dashboard, and supporting docs/scripts.

## Summary
- **CRITICAL:** 2 issues (command injection in dashboard approvals and session send)
- **HIGH:** 4 issues (insecure default auth token, token leakage via query params, webhook token exposure in process list, state directory permissions not enforced on existing dir)
- **MEDIUM:** 4 issues (notification error handling, registry race conditions, daemon double-start race, dashboard polling performance risk)
- **LOW:** 3 issues (undefined variable, inconsistent shell strictness, missing `-l` for tmux send in session-send)

Focus areas emphasized in request:
- Command injection risks in tmux/shell commands (addressed under CRITICAL)
- Webhook token handling security (HIGH)
- Session registry security (HIGH/MEDIUM)
- Monitor daemon reliability (MEDIUM)
- Error handling in notification system (MEDIUM)

---

## CRITICAL

### CRIT-01: Command Injection via Dashboard Approval Action
**File:** `dashboard/tmux-dashboard.js:193-199`

**Issue:** `action` and `name` are interpolated into a shell command via `execSync`. Both values are attacker-controlled via Socket.IO events, allowing shell injection (e.g., `action="approve; rm -rf /"`).

**Evidence (code):**
```js
execSync(`"${scriptPath}" ${action} "${name}"`, { timeout: 5000 });
```

**Impact:** Arbitrary command execution on the host running the dashboard.

**Recommended fix:** Use `execFileSync` (no shell) and validate inputs.

**Example fix:**
```js
const { execFileSync } = require('child_process');

function assertSafeSessionName(name) {
  if (!/^[a-zA-Z0-9_-]+$/.test(name)) throw new Error('Invalid session name');
}
function assertSafeAction(action) {
  if (!['approve', 'always', 'deny'].includes(action)) throw new Error('Invalid action');
}

const scriptPath = path.join(__dirname, '../lib/handle-approval.sh');
execFileSync(scriptPath, [action, name], { timeout: 5000 });
```

---

### CRIT-02: Command Injection via Dashboard Session Send
**File:** `dashboard/tmux-dashboard.js:206-212`

**Issue:** `text` is interpolated into a shell command. Only double quotes are escaped; `$()` or backticks still execute.

**Evidence (code):**
```js
execSync(`tmux send-keys -t "${name}" -l -- "${text.replace(/"/g, '\\"')}"`, { timeout: 5000 });
```

**Impact:** Arbitrary command execution on the host.

**Recommended fix:** Use `execFileSync` and pass args as an array. Validate session name.

**Example fix:**
```js
execFileSync('tmux', ['send-keys', '-t', name, '-l', '--', text], { timeout: 5000 });
execFileSync('tmux', ['send-keys', '-t', name, 'Enter'], { timeout: 5000 });
```

---

## HIGH

### HIGH-01: Insecure Default Dashboard Token
**File:** `dashboard/tmux-dashboard.js:32-36`

**Issue:** When no env/config token is available, the server boots with `INSECURE_DEFAULT_TOKEN`.

**Impact:** Anyone who knows or guesses the default can access live session content and send inputs.

**Recommended fix:** Refuse to start if no token is provided.

**Example fix:**
```js
if (DASHBOARD_TOKEN === 'INSECURE_DEFAULT_TOKEN') {
  console.error('[Dashboard] Refusing to start without DASHBOARD_TOKEN');
  process.exit(1);
}
```

---

### HIGH-02: Token Leakage via Query Parameters
**File:** `dashboard/tmux-dashboard.js:40-47`, `dashboard/tmux-dashboard.js:153-161`

**Issue:** Auth token accepted via `?token=` in HTTP and Socket.IO. Query params leak to logs, history, and referrers.

**Impact:** Token leakage enables unauthorized access.

**Recommended fix:** Only accept tokens via headers or Socket.IO auth payload.

**Example fix:**
```js
const token = req.headers['x-dashboard-token'];
```

---

### HIGH-03: Webhook Token Exposed in Process List
**File:** `lib/send-notification.sh:108-110`

**Issue:** Token is passed to `curl` as a command-line arg (`-H "Authorization: Bearer ..."`). Local users can read it via `ps`/`/proc`.

**Impact:** Token theft enables unauthorized notifications and potentially broader webhook abuse.

**Recommended fix:** Pass headers via a temp file or stdin and restrict perms.

**Example fix:**
```bash
umask 077
HDR_FILE="$(mktemp)"
printf 'Authorization: Bearer %s\n' "$WEBHOOK_TOKEN" > "$HDR_FILE"

curl -fsS -X POST "$WEBHOOK_URL" \
  -H @"$HDR_FILE" \
  -H "Content-Type: application/json" \
  -d "{...}"
rm -f "$HDR_FILE"
```

---

### HIGH-04: State Directory Permissions Not Enforced If Pre-Existing
**File:** `nebo-monitor.sh:21-26`

**Issue:** Permissions are only set on first creation. If `/tmp/nebo-orchestrator` exists with loose perms, sensitive files can be exposed.

**Impact:** Channel registry and notification state can be read/modified by other users.

**Recommended fix:** Enforce permissions every run and lock down logs.

**Example fix:**
```bash
install -d -m 700 "$STATE_DIR"
install -d -m 700 "$NOTIFY_STATE_DIR"
touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
```

---

## MEDIUM

### MED-01: Notification Failures Not Detected
**File:** `lib/send-notification.sh:108-117`

**Issue:** `curl -s` doesn’t fail on HTTP errors; monitor may log success even when webhook rejects request.

**Impact:** Silent notification failure; approvals missed.

**Recommended fix:** Use `-f` and propagate errors.

**Example fix:**
```bash
curl -fsS -X POST "$WEBHOOK_URL" ...
```

---

### MED-02: Session Registry Race Conditions
**File:** `lib/register-session-channel.sh:34-53`, `nebo-monitor.sh:112-123`

**Issue:** Updates to `channel-registry.json` are not locked. Concurrent writers can lose updates.

**Impact:** Wrong channel routing or lost mapping.

**Recommended fix:** Add `flock` around registry writes.

**Example fix:**
```bash
(
  flock 9
  # update registry
) 9>"$STATE_DIR/channel-registry.lock"
```

---

### MED-03: Monitor Daemon Double-Start Race
**File:** `nebo-monitor.sh:83-96`

**Issue:** PID file creation is not atomic; two starts can both proceed before PID is written.

**Impact:** Multiple daemons run, duplicate notifications.

**Recommended fix:** Use a lock file to enforce singleton.

**Example fix:**
```bash
LOCK_FILE="$STATE_DIR/nebo-monitor.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Monitor already running"; exit 1; }
```

---

### MED-04: Blocking Poll Loop at High Frequency
**File:** `dashboard/tmux-dashboard.js:14, 221-222, 137-149`

**Issue:** `execSync` blocks the Node event loop. At 500ms polling, multiple sessions can cause lag and dropped socket responsiveness.

**Impact:** Dashboard responsiveness degrades; potential missed user inputs.

**Recommended fix:** Move to async `execFile`, use queues, and/or increase polling interval.

---

## LOW

### LOW-01: Undefined Variable in Approval Response
**File:** `lib/approval-respond.sh:48`

**Issue:** `$NORMALIZED` is never set.

**Impact:** Incorrect output, minor clarity issue.

**Recommended fix:** Set `NORMALIZED="$RESPONSE"` or remove reference.

---

### LOW-02: Inconsistent Shell Strictness
**Files:** `lib/send-notification.sh:10`, `lib/approval-respond.sh:6`, `lib/session-send.sh:5`

**Issue:** Scripts use `set -e` but not `-u` or `pipefail`.

**Impact:** Silent failures or use of unset variables.

**Recommended fix:** Standardize on `set -euo pipefail` when safe.

---

### LOW-03: `session-send.sh` Does Not Use Literal Send
**File:** `lib/session-send.sh:126-129`

**Issue:** `tmux send-keys` without `-l` can interpret special key sequences.

**Impact:** Non-deterministic input behavior.

**Recommended fix:** Use `tmux send-keys -l -- "$COMMAND"`.

---

## Priority Remediation Order
1. **CRIT-01/02:** Eliminate shell injection in dashboard by replacing `execSync` with `execFileSync` and validating input.
2. **HIGH-01/02:** Enforce strong auth for dashboard (no default token, no query-param tokens).
3. **HIGH-03:** Hide webhook token from process list and enforce HTTP error checking.
4. **HIGH-04/MED-02/03:** Enforce permissions and add locking for registry and daemon.
5. **MED-04:** Reduce polling pressure and remove blocking calls.
6. **LOW items:** Clean up script strictness and minor inconsistencies.

---

## Notes On Dependency CVEs
No lockfile (`package-lock.json` or `npm-shrinkwrap.json`) is present in `dashboard/`, so dependency CVEs cannot be reliably assessed from `package.json` alone. Run `npm install` and `npm audit` inside `dashboard/` for a definitive report.

---

## Appendix: Files Reviewed
- `nebo-session.sh`
- `nebo-monitor.sh`
- `start-session.sh`
- `lib/send-notification.sh`
- `lib/session-status.sh`
- `lib/session-send.sh`
- `lib/handle-approval.sh`
- `lib/approval-respond.sh`
- `lib/register-session-channel.sh`
- `lib/session-cleanup.sh`
- `dashboard/tmux-dashboard.js`
- `dashboard/package.json`
- `docs/SECURITY_FIXES.md`
