# Clawdpods

Run multiple isolated [OpenClaw](https://github.com/openclaw/openclaw) bots in Docker containers.

## Quick Start

```bash
# 1. Build image
cd ~/clawdpods && docker build -t openclaw:local .

# 3. Onboard a bot (interactive OAuth)
docker compose run --rm -it fitness-bot-cli onboard

# 4. Start the bot
docker compose up -d fitness-bot

# 5. Approve Telegram pairing (when prompted)
docker compose run --rm fitness-bot-cli pairing approve telegram <CODE>
```

## Bots

| Bot | Port | Config | Workspace |
|-----|------|--------|-----------|
| father-bot | 18799 | `~/.clawdpods/father-bot/` | `~/clawdpods/` |
| fitness-bot | 18800 | `~/.clawdpods/fitness-bot/` | `~/fitness-workspace/` |
| cb-bot | 18801 | `~/.clawdpods/cb-bot/` | `~/cb-workspace/` |
| general-bot | 18802 | `~/.clawdpods/general-bot/` | `~/general-workspace/` |

**father-bot** can create new bots via `/new-bot <name>`.

## Commands

```bash
docker compose up -d <bot>           # Start
docker compose down                  # Stop all
docker compose logs -f <bot>         # Logs
docker compose run --rm -it <bot>-cli onboard                      # Onboard
docker compose run --rm <bot>-cli pairing approve telegram <CODE>  # Pair Telegram
```

## Adding a Bot Manually

1. Create directories:
   ```bash
   mkdir -p ~/.clawdpods/<bot> ~/<bot>-workspace
   ```

2. Add to `docker-compose.yml` (copy existing bot, change name + port)

3. Onboard and start:
   ```bash
   docker compose run --rm -it <bot>-cli onboard
   docker compose up -d <bot>
   ```
