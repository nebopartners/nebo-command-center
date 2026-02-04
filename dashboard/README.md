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

Cloudflare Tunnel provides secure public access to your dashboard without exposing ports directly to the internet. It also provides:
- Automatic HTTPS/TLS encryption
- DDoS protection
- Optional email/SSO authentication via Cloudflare Access
- No need to open firewall ports

### Prerequisites

1. **Cloudflare account** with a domain added
2. **Cloudflare Zero Trust** account (free tier works)
3. **cloudflared** CLI installed

### Step 1: Install cloudflared

**Linux:**
```bash
# Download latest release
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb

# Install
sudo dpkg -i cloudflared-linux-amd64.deb

# Verify
cloudflared --version
```

**macOS:**
```bash
brew install cloudflared
```

**Other platforms:** https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/

### Step 2: Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This opens a browser window to authenticate. Select your domain.

A credentials file is saved to `~/.cloudflared/cert.pem`

### Step 3: Create a Tunnel

```bash
cloudflared tunnel create nebo-dashboard
```

**Output:**
```
Tunnel credentials written to /home/matt/.cloudflared/<TUNNEL_ID>.json
Created tunnel nebo-dashboard with id <TUNNEL_ID>
```

**Save your tunnel ID** - you'll need it for configuration.

### Step 4: Configure the Tunnel

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /home/matt/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: nebo.yourdomain.com
    service: http://localhost:3333
  - service: http_status:404
```

**Replace:**
- `<TUNNEL_ID>` with your actual tunnel ID
- `nebo.yourdomain.com` with your desired subdomain

**Example (real config):**
```yaml
tunnel: a1b2c3d4-e5f6-7890-abcd-ef1234567890
credentials-file: /home/matt/.cloudflared/a1b2c3d4-e5f6-7890-abcd-ef1234567890.json

ingress:
  - hostname: mg-admin.nebopartners.com
    service: http://localhost:3333
  - service: http_status:404
```

### Step 5: Create DNS Record

```bash
cloudflared tunnel route dns nebo-dashboard nebo.yourdomain.com
```

**Output:**
```
Added CNAME nebo.yourdomain.com which will route to tunnel <TUNNEL_ID>
```

This creates a CNAME record in your Cloudflare DNS pointing to the tunnel.

### Step 6: Start the Dashboard

In one terminal:
```bash
cd ~/nebo-command-center/dashboard
node tmux-dashboard.js
```

**Output:**
```
[Dashboard] Server listening on port 3333
[Dashboard] Dashboard token: abc123...
```

### Step 7: Start the Tunnel

In another terminal (or use systemd for persistent service):
```bash
cloudflared tunnel run nebo-dashboard
```

**Output:**
```
2026-02-04T14:30:00Z INF Starting tunnel tunnelID=<TUNNEL_ID>
2026-02-04T14:30:01Z INF Connection registered connIndex=0
2026-02-04T14:30:01Z INF Connection registered connIndex=1
2026-02-04T14:30:01Z INF Connection registered connIndex=2
2026-02-04T14:30:01Z INF Connection registered connIndex=3
```

### Step 8: Access Your Dashboard

```bash
TOKEN=$(jq -r '.hooks.token' ~/.openclaw/openclaw.json)
echo "Dashboard: https://nebo.yourdomain.com/?token=$TOKEN"
```

**Example:**
```
https://mg-admin.nebopartners.com/?token=abc123def456...
```

### Step 9: Setup Systemd Service (Optional but Recommended)

**Dashboard service:**
```bash
sudo tee /etc/systemd/system/nebo-dashboard.service > /dev/null << EOF
[Unit]
Description=NEBO Command Center Dashboard
After=network.target

[Service]
Type=simple
User=matt
WorkingDirectory=/home/matt/nebo-command-center/dashboard
ExecStart=/usr/bin/node tmux-dashboard.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable nebo-dashboard
sudo systemctl start nebo-dashboard
```

**Cloudflare Tunnel service:**
```bash
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

### Step 10: Add Cloudflare Access (Extra Security Layer)

**In Cloudflare Dashboard:**
1. Go to **Zero Trust** → **Access** → **Applications**
2. Click **Add an application** → **Self-hosted**
3. **Application name:** NEBO Dashboard
4. **Subdomain:** nebo
5. **Domain:** yourdomain.com
6. Click **Next**
7. **Add a policy:**
   - Policy name: Team Access
   - Action: Allow
   - Include: Emails ending in: `@yourdomain.com` (or specific emails)
8. Click **Next** → **Add application**

Now when users visit `https://nebo.yourdomain.com`, they'll be prompted to authenticate via email/Google/GitHub before accessing the dashboard.

### Verification

```bash
# Test tunnel is running
curl -I https://nebo.yourdomain.com

# Should return HTTP/2 200 (or 401 if Access is enabled)

# Test with token
TOKEN=$(jq -r '.hooks.token' ~/.openclaw/openclaw.json)
curl "https://nebo.yourdomain.com/?token=$TOKEN"
# Should return dashboard HTML
```

### Troubleshooting

**Tunnel not connecting:**
```bash
# Check tunnel status
cloudflared tunnel info nebo-dashboard

# Check tunnel logs
journalctl -u cloudflared -f

# Verify credentials file exists
ls -la ~/.cloudflared/<TUNNEL_ID>.json
```

**Dashboard not loading:**
```bash
# Check dashboard is running locally
curl http://localhost:3333

# Check cloudflared config
cat ~/.cloudflared/config.yml

# Test webhook
TOKEN=$(jq -r '.hooks.token' ~/.openclaw/openclaw.json)
curl "http://localhost:3333/?token=$TOKEN"
```

**DNS not resolving:**
```bash
# Check DNS record
dig nebo.yourdomain.com

# Should show CNAME to <TUNNEL_ID>.cfargotunnel.com
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

## Discord Integration

The dashboard works seamlessly with Discord notifications via OpenClaw.

### How It Works

1. **User invokes command in Discord**: `/plan feature-x`
2. **OpenClaw starts session via NEBO**: Registers session → Discord channel mapping
3. **Monitor daemon watches session**: Detects approval prompts
4. **Sends notification to Discord**: Via OpenClaw webhook
5. **Dashboard shows real-time status**: WebSocket updates every 500ms

### Setting Up Discord Notifications

**Step 1: Configure OpenClaw webhook**

Edit `~/.openclaw/openclaw.json`:
```json
{
  "hooks": {
    "enabled": true,
    "token": "YOUR_SECURE_TOKEN_HERE"
  },
  "channels": {
    "discord": {
      "token": "YOUR_DISCORD_BOT_TOKEN",
      "guilds": {
        "YOUR_GUILD_ID": {
          "name": "Your Server Name",
          "channels": {
            "YOUR_CHANNEL_ID": "channel-name"
          }
        }
      }
    }
  }
}
```

**Step 2: Test webhook**

```bash
TOKEN=$(jq -r '.hooks.token' ~/.openclaw/openclaw.json)
CHANNEL_ID="1466888482793459813"  # Your Discord channel ID

curl -X POST http://127.0.0.1:18789/hooks/agent \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"message\":\"✅ NEBO webhook test\",\"deliver\":true,\"channel\":\"discord\",\"to\":\"channel:$CHANNEL_ID\"}"
```

**Expected:** Test message appears in Discord

**Step 3: Get Discord channel ID**

In Discord:
1. Enable **Developer Mode**: User Settings → Advanced → Developer Mode
2. Right-click your channel → **Copy ID**
3. Use this ID in commands: `discord:channel:1466888482793459813`

### Using Dashboard with Discord

**Dashboard shows:**
- All active Claude Code / Codex sessions
- Real-time terminal output
- Approval status (Waiting / Working / Idle)

**From Discord, users can:**
- Send `/plan`, `/implement`, `/review` commands
- Receive approval notifications
- Respond with: `approve claude-1234567890` / `always claude-1234567890` / `deny claude-1234567890`

**From Dashboard, admins can:**
- Monitor all sessions in real-time
- Click **Approve** / **Always** / **Deny** buttons
- Send custom text to sessions
- View full terminal output with ANSI colors

### Approval Flow

```
Discord User: /plan new-feature
     ↓
OpenClaw extracts: discord:channel:1466888482793459813
     ↓
NEBO starts session: claude-1770236959
     ↓
Monitor detects approval prompt
     ↓
Sends notification to Discord: "🚦 Claude Code needs approval..."
     ↓
[Option 1] User in Discord: "approve claude-1770236959"
[Option 2] Admin in Dashboard: Clicks "Approve" button
     ↓
Session continues execution
     ↓
Result posted to Discord when complete
```

## Security Best Practices

1. **Use strong tokens** - Generate with `openssl rand -hex 32`
2. **Keep tokens secret** - Don't commit to git, use environment variables
3. **Use Cloudflare Tunnel** - Never expose port 3333 directly to internet
4. **Enable Cloudflare Access** - Add email/SSO authentication for dashboard
5. **Discord bot permissions** - Only grant necessary permissions (Read Messages, Send Messages, Add Reactions)
6. **Rotate tokens** - Change tokens periodically

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
