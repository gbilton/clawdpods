# Clawdpods

Run multiple isolated OpenClaw bots, each with its own configuration, credentials, and workspace.

## Architecture

Each bot runs as a separate Docker container with:
- **Config directory**: `~/.openclaw-bots/<bot-name>/` - stores credentials, settings, session history
- **Workspace directory**: `~/<bot-name>-workspace/` - files the bot can access

## Current Bots

| Bot | Port | Config | Workspace |
|-----|------|--------|-----------|
| father-bot | 18799 | `~/.openclaw-bots/father-bot/` | `~/clawdpods/` |
| fitness-bot | 18800 | `~/.openclaw-bots/fitness-bot/` | `~/fitness-workspace/` |
| cb-bot | 18801 | `~/.openclaw-bots/cb-bot/` | `~/cb-workspace/` |
| general-bot | 18802 | `~/.openclaw-bots/general-bot/` | `~/general-workspace/` |

## Father Bot

The `father-bot` is a special bot that can create other bots. It has access to:
- `~/clawdpods/` - to edit docker-compose.yml
- `~/.openclaw-bots/` - to create new bot config directories
- `~/` - to create new workspace directories

Use `/new-bot <bot-name>` to create a new bot through father-bot.

## Initial Setup

### 1. Clone the OpenClaw repository

```bash
git clone https://github.com/openclaw/openclaw.git ~/openclaw-src
```

### 2. Build the base OpenClaw image

```bash
cd ~/openclaw-src
docker build -t openclaw:local .
```

### 3. Build the extended image with gemini-cli

The Dockerfile in this repo extends the base image with gemini-cli (required for OAuth):

```bash
cd ~/clawdpods
docker build -t openclaw:local .
```

### 4. Create bot directories

```bash
mkdir -p ~/.openclaw-bots/fitness-bot
mkdir -p ~/.openclaw-bots/cb-bot
mkdir -p ~/.openclaw-bots/general-bot

mkdir -p ~/fitness-workspace
mkdir -p ~/cb-workspace
mkdir -p ~/general-workspace
```

### 5. Run onboarding for each bot

Onboarding sets up OAuth authentication. Run interactively for each bot:

```bash
cd ~/clawdpods
docker compose run --rm -it fitness-bot-cli onboard
docker compose run --rm -it cb-bot-cli onboard
docker compose run --rm -it general-bot-cli onboard
```

Follow the prompts - it will open a browser for OAuth authentication.

### 6. Start the bots

```bash
docker compose up -d fitness-bot cb-bot general-bot
```

### 7. Connect Telegram (optional)

When you message the bot on Telegram, it will show a pairing code:

```
Pairing code: XXXXXX
Ask the bot owner to approve with:
openclaw pairing approve telegram <code>
```

Approve it with:

```bash
docker compose run --rm fitness-bot-cli pairing approve telegram XXXXXX
```

## Adding a New Bot

### 1. Create directories

```bash
mkdir -p ~/.openclaw-bots/<bot-name>
mkdir -p ~/<bot-name>-workspace
```

### 2. Add services to docker-compose.yml

Add both gateway and CLI services. Choose an unused port (18803, 18804, etc.):

```yaml
  <bot-name>:
    image: openclaw:local
    container_name: <bot-name>
    restart: unless-stopped
    environment:
      HOME: /home/node
      TERM: xterm-256color
    volumes:
      - ~/.openclaw-bots/<bot-name>:/home/node/.openclaw:rw
      - ~/<bot-name>-workspace:/home/node/.openclaw/workspace:rw
    ports:
      - "<host-port>:18789"
    init: true
    command: ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789"]

  <bot-name>-cli:
    image: openclaw:local
    container_name: <bot-name>-cli
    environment:
      HOME: /home/node
      TERM: xterm-256color
      BROWSER: echo
    volumes:
      - ~/.openclaw-bots/<bot-name>:/home/node/.openclaw:rw
      - ~/<bot-name>-workspace:/home/node/.openclaw/workspace:rw
    stdin_open: true
    tty: true
    init: true
    entrypoint: ["node", "dist/index.js"]
    profiles: ["cli"]
```

### 3. Run onboarding

```bash
docker compose run --rm -it <bot-name>-cli onboard
```

### 4. Start the bot

```bash
docker compose up -d <bot-name>
```

## Common Commands

```bash
# Start all bots
docker compose up -d fitness-bot cb-bot general-bot

# Stop all bots
docker compose down

# View logs
docker compose logs -f <bot-name>

# Restart a specific bot
docker compose restart <bot-name>

# Run onboarding for a bot
docker compose run --rm -it <bot-name>-cli onboard

# Approve Telegram pairing
docker compose run --rm <bot-name>-cli pairing approve telegram <code>

# Add Telegram bot token
docker compose run --rm -it <bot-name>-cli channels add --channel telegram --token "<BOT_TOKEN>"

# Check bot's workspace
docker exec <bot-name> ls /home/node/.openclaw/workspace

# Check bot's config
docker exec <bot-name> cat /home/node/.openclaw/openclaw.json
```

## Configuration Persistence

Configuration persists across container restarts because credentials and settings are stored on the host filesystem in `~/.openclaw-bots/<bot-name>/`, not inside the container.

**What persists:**
- OAuth tokens and credentials
- `openclaw.json` settings
- Session history and agent data

**What does NOT persist (reset on container restart):**
- Running processes/sessions inside the container
- Any files written inside the container (outside mounted volumes)

## Optional Hardening

### Read-only workspace
```yaml
volumes:
  - ~/<bot-name>-workspace:/home/node/.openclaw/workspace:ro
```

### Disable network access
```yaml
<bot-name>:
  network_mode: none
```

### Resource limits
```yaml
<bot-name>:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 4G
```

### Disable specific tools
Add to `~/.openclaw-bots/<bot-name>/openclaw.json`:
```json
{
  "agents": {
    "defaults": {
      "tools": {
        "deny": ["browser", "cron"]
      }
    }
  }
}
```

## Troubleshooting

### Port already in use
If you get "address already in use" errors, check what's using the port:
```bash
ss -tlnp | grep 18800
```

Kill the process or change the port in docker-compose.yml.

### OAuth errors about Gemini CLI
Rebuild the image with gemini-cli:
```bash
cd ~/clawdpods
docker build -t openclaw:local .
```

### Container won't start
Check logs:
```bash
docker compose logs <bot-name>
```

### Telegram pairing
1. Message your bot on Telegram
2. It will show a pairing code
3. Run: `docker compose run --rm <bot-name>-cli pairing approve telegram <code>`
