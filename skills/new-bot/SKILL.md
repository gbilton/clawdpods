---
name: new-bot
description: Create and fully provision a new clawdpods bot. Use when the user says /new-bot, "create a new bot", "add a bot", or wants to set up a new OpenClaw bot instance. Handles directory structure, config files, API keys, Telegram setup, and docker-compose entries — no interactive onboarding or pairing needed.
---

# New Bot

Fully provisions a new clawdpods bot by running `scripts/setup-bot.sh`.

## Requirements

Two pieces of info from the user:

1. **Bot name** (e.g. `headhunter-bot`) — lowercase, hyphens ok
2. **Telegram bot token** — user gets this from @BotFather in Telegram

## Usage

```bash
bash /home/node/clawdpods/skills/new-bot/scripts/setup-bot.sh <bot-name> <telegram-bot-token>
```

The script automatically:
- Creates all config directories under `/home/node/bot-configs/<name>/`
- Creates workspace at `/home/node/clawdpods-workspaces/<name>/`
- Writes `openclaw.json` with model config and the Telegram bot token
- Copies the Anthropic API key from your (father-bot's) own auth-profiles
- Pre-populates `telegram-allowFrom.json` with the user's Telegram ID (from your own config) — **no pairing flow needed**
- Finds the next available port and adds service entries to `docker-compose.override.yml`

## Flow

1. Ask the user for the **bot name** and **Telegram bot token** (remind them to create one via @BotFather if they don't have it)
2. Run the script
3. Tell the user to start the bot: `docker compose up -d <bot-name>`
4. The bot is immediately reachable on Telegram — no onboarding or pairing commands needed

## Optional: Telegram user ID override

If the user wants a different Telegram user ID than yours, pass it as a third argument:

```bash
bash /home/node/clawdpods/skills/new-bot/scripts/setup-bot.sh <bot-name> <telegram-bot-token> <telegram-user-id>
```
