# Clawdpods

Run multiple isolated [OpenClaw](https://github.com/openclaw/openclaw) bots in Docker containers.

## What is this?

OpenClaw is a framework for building conversational AI bots that integrate with platforms like Telegram. This project provides Docker infrastructure to run multiple independent bot instances, each with isolated configuration and workspace directories.

## Architecture

Each bot consists of two Docker services:

- **Gateway** (`<bot-name>`) - Long-running service that handles connections. Exposes a port for the OpenClaw web UI.
- **CLI** (`<bot-name>-cli`) - On-demand container for administration tasks like onboarding and pairing.

```
┌─────────────────────────────────────────────────────────┐
│  Host Machine                                           │
│                                                         │
│  ~/.clawdpods/                                          │
│  ├── father-bot/     → Bot configs (OAuth tokens, etc.) │
│  └── example-bot/                                       │
│                                                         │
│  ~/example-bot-workspace/  → Bot's working directory    │
│                                                         │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │  father-bot     │  │  your-bot       │              │
│  │  :18799         │  │  :18800+        │              │
│  └─────────────────┘  └─────────────────┘              │
└─────────────────────────────────────────────────────────┘
```

### Why this structure?

- **Isolation**: Each bot has its own config and workspace. They can't interfere with each other.
- **Persistence**: Configs and workspaces live on the host, surviving container rebuilds.
- **Gateway + CLI pattern**: The gateway runs 24/7 while CLI containers are ephemeral for admin tasks.
- **Shared image**: All bots use the same Docker image, saving disk space.

## Prerequisites

- Docker and Docker Compose
- ~2GB disk space for the image
- Accounts for services you want to integrate (Telegram, etc.)

## Quick Start

```bash
# 1. Clone and build
git clone https://github.com/gbilton/clawdpods.git
cd clawdpods
docker build -t openclaw:local .

# 2. Create directories (required - must exist before running containers)
mkdir -p ~/.clawdpods/father-bot

# 3. Onboard the bot (interactive OAuth flow)
docker compose run --rm -it father-bot-cli onboard

# 4. Start the bot
docker compose up -d father-bot

# 5. Pair with Telegram (when prompted)
docker compose run --rm father-bot-cli pairing approve telegram <CODE>
```

## Included Bots

| Bot | Port | Purpose |
|-----|------|---------|
| `father-bot` | 18799 | Privileged bot that can create new bots via `/new-bot` |
| `example-bot` | 18810 | Template (commented out) - uncomment or copy for your own bots |

## Commands

```bash
# Start a bot
docker compose up -d <bot-name>

# Stop all bots
docker compose down

# View logs
docker compose logs -f <bot-name>

# Run CLI commands
docker compose run --rm -it <bot-name>-cli onboard
docker compose run --rm <bot-name>-cli pairing approve telegram <CODE>
```

## Adding More Bots

### Option 1: Use father-bot

If you have father-bot running, send it `/new-bot <name>` and it will create the bot for you.

### Option 2: Manual

1. Create directories:
   ```bash
   mkdir -p ~/.clawdpods/<bot-name> ~/<bot-name>-workspace
   ```

2. Copy the `example-bot` service block in `docker-compose.yml` and modify:
   - Service names: `<bot-name>` and `<bot-name>-cli`
   - Container names
   - Volume paths
   - Port (increment from last used)

3. Onboard and start:
   ```bash
   docker compose run --rm -it <bot-name>-cli onboard
   docker compose up -d <bot-name>
   ```

## Personal Configurations

To keep personal bots separate from the public config, create `docker-compose.override.yml`:

```yaml
# docker-compose.override.yml (gitignored)
services:
  my-private-bot:
    image: openclaw:local
    # ... your config
```

Docker Compose automatically merges this with `docker-compose.yml`. Your personal bots stay local and won't be committed to git.

## Volume Mounts Explained

| Mount | Purpose |
|-------|---------|
| `~/.clawdpods/<bot>/` → `/home/node/.openclaw` | Bot's config directory (OAuth tokens, settings) |
| `~/<bot>-workspace/` → `/home/node/.openclaw/workspace` | Bot's working directory |
| `~/.gemini/` → `/home/node/.gemini` | Gemini CLI credentials (optional) |
| `~/.claude/` → `/home/node/.claude` | Claude Code credentials (optional) |
| `~/.ssh/key` → `/home/node/.ssh/id_ed25519` | SSH key for git operations (optional) |

## Troubleshooting

**"Permission denied" errors**

Bot directories must exist before running containers. Docker creates missing directories as root, causing permission issues.

When using `/new-bot`, directories are created automatically. For manual setup (including father-bot), create them first:
```bash
mkdir -p ~/.clawdpods/<bot-name>
```

**OAuth flow shows URL but doesn't open browser**

Expected behavior in Docker. Copy the URL and open it manually in your browser.

**Bot won't start**

Check if the port is already in use:
```bash
docker compose logs <bot-name>
ss -tlnp | grep 18800
```
