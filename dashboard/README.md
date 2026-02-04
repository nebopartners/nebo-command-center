# Nebo Dev Ops Dashboard

Real-time web dashboard for monitoring AI coding agent sessions (Claude Code, Codex) with authentication.

## Security

**Authentication is REQUIRED** - The dashboard requires a token to access.

### Token Configuration

**Option 1: Use OpenClaw hooks token (recommended)**

The dashboard automatically reads `hooks.token` from `~/.openclaw/openclaw.json`:

```json
{
  "hooks": {
    "token": "your-secure-token-here"
  }
}
```

**Option 2: Environment variable**

```bash
export DASHBOARD_TOKEN="your-secure-token-here"
node tmux-dashboard.js
```

**Security Note:** If no token is found, dashboard will start with an INSECURE_DEFAULT_TOKEN and log a warning. This is NOT SECURE for production use.

## Running the Dashboard

### Install Dependencies

```bash
cd dashboard
npm install
```

### Start the Server

```bash
node tmux-dashboard.js
```

Server starts on port 3333 (configurable via `PORT` environment variable).

### Access the Dashboard

**Via Cloudflare Tunnel (recommended):**
```
https://mg-admin.nebopartners.com/?token=YOUR_TOKEN_HERE
```

**Local access:**
```
http://localhost:3333/?token=YOUR_TOKEN_HERE
```

**Example:**
```bash
# Get your token
TOKEN=$(jq -r '.hooks.token' ~/.openclaw/openclaw.json)

# Open in browser
open "http://localhost:3333/?token=$TOKEN"
```

## Cloudflare Tunnel Setup

Cloudflare Tunnel provides an additional layer of authentication and encryption.

### Configuration

Add to your Cloudflare Tunnel config:

```yaml
tunnel: <tunnel-id>
credentials-file: /path/to/credentials.json

ingress:
  - hostname: mg-admin.nebopartners.com
    service: http://localhost:3333
  - service: http_status:404
```

## Features

- **Real-time session monitoring** - See all AI coding agent sessions
- **Live terminal output** - ANSI-colored terminal display
- **Quick approval actions** - Approve/Always/Deny buttons
- **Text input** - Send custom commands to sessions
- **Approval shortcuts** - Type 1/2/3 for quick approvals
- **Session status** - Working, Waiting, Idle indicators
- **Auto-refresh** - Updates every 500ms

## API Endpoints

### GET /

Serves the dashboard HTML (requires authentication).

**Headers:**
- `x-dashboard-token: YOUR_TOKEN`

**Query:**
- `?token=YOUR_TOKEN`

### WebSocket (Socket.IO)

**Authentication:**
```javascript
const socket = io({
  auth: { token: 'YOUR_TOKEN' },
  query: { token: 'YOUR_TOKEN' }
});
```

**Events:**
- `session:add` - New session detected
- `session:update` - Session content updated
- `session:remove` - Session ended
- `session:approve` - Quick approval action (1=approve, 2=always, 3=deny)
- `session:send` - Send text to session
- `approval:result` - Approval result feedback

## Security Best Practices

1. **Use strong tokens** - Generate with `openssl rand -hex 32`
2. **Keep tokens secret** - Don't commit to git, use environment variables
3. **Use Cloudflare Tunnel** - Never expose port 3333 directly to internet
4. **Enable Cloudflare Access** - Add email/SSO authentication
5. **Rotate tokens** - Change tokens periodically

## Troubleshooting

### "Authentication Required" error

- Check token is included in URL: `?token=YOUR_TOKEN`
- Verify token matches the configured token
- Check browser console for errors

### "Invalid token" error

- Token mismatch - verify you're using the correct token
- Check `~/.openclaw/openclaw.json` for `hooks.token` value
- Or check `DASHBOARD_TOKEN` environment variable

### Dashboard not loading

- Verify server is running: `curl http://localhost:3333`
- Check firewall rules
- Verify port 3333 is not in use: `lsof -i :3333`

## Related

- **Session starter:** `../nebo-session.sh` - Start new Claude Code sessions
- **Monitor daemon:** `../nebo-monitor.sh` - Polls sessions, sends Discord notifications
- **Session handlers:** `../lib/` - Approval handlers, status checkers

---

**Status:** Secured ✅
