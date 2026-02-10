#!/bin/bash
set -euo pipefail

# setup-bot.sh - Automate new bot provisioning for clawdpods
#
# Usage: setup-bot.sh <bot-name> <telegram-bot-token> [telegram-user-id]
#
# Paths assume execution inside father-bot's container:
#   /home/node/bot-configs/     -> host ~/.clawdpods/
#   /home/node/clawdpods-workspaces/ -> host ~/clawdpods-workspaces/
#   /home/node/clawdpods/       -> host ~/clawdpods/
#   /home/node/.openclaw/       -> host ~/.clawdpods/father-bot/

BOT_NAME="${1:?Usage: setup-bot.sh <bot-name> <telegram-bot-token> [telegram-user-id]}"
TELEGRAM_BOT_TOKEN="${2:?Usage: setup-bot.sh <bot-name> <telegram-bot-token> [telegram-user-id]}"

BOT_CONFIG="/home/node/bot-configs/${BOT_NAME}"
BOT_WORKSPACE="/home/node/clawdpods-workspaces/${BOT_NAME}"
FATHER_CONFIG="/home/node/.openclaw"
COMPOSE_OVERRIDE="/home/node/clawdpods/docker-compose.override.yml"
COMPOSE_MAIN="/home/node/clawdpods/docker-compose.yml"

# Get telegram user ID from father-bot's config, or use provided one
if [ -n "${3:-}" ]; then
    TELEGRAM_USER_ID="$3"
elif [ -f "${FATHER_CONFIG}/credentials/telegram-allowFrom.json" ]; then
    TELEGRAM_USER_ID=$(grep -oP '"[0-9]+"' "${FATHER_CONFIG}/credentials/telegram-allowFrom.json" | head -1 | tr -d '"')
else
    echo "ERROR: No telegram user ID provided and couldn't read from father-bot config"
    exit 1
fi

# Check if bot already exists
if [ -d "${BOT_CONFIG}/agents" ]; then
    echo "ERROR: Bot '${BOT_NAME}' already appears to be fully set up (agents dir exists)"
    exit 1
fi

# Generate random gateway token
GATEWAY_TOKEN=$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')

# Get Anthropic API key from father-bot's auth-profiles
FATHER_AUTH="${FATHER_CONFIG}/agents/main/agent/auth-profiles.json"
if [ ! -f "$FATHER_AUTH" ]; then
    echo "ERROR: Cannot read father-bot auth-profiles at ${FATHER_AUTH}"
    exit 1
fi
ANTHROPIC_KEY=$(grep -oP '"token":\s*"[^"]+"' "$FATHER_AUTH" | head -1 | grep -oP '"[^"]+"\s*$' | tr -d '"')

if [ -z "$ANTHROPIC_KEY" ]; then
    echo "ERROR: Could not extract Anthropic API key from father-bot"
    exit 1
fi

echo "Setting up bot: ${BOT_NAME}"
echo "  Telegram bot token: ${TELEGRAM_BOT_TOKEN:0:10}..."
echo "  Telegram user ID: ${TELEGRAM_USER_ID}"

# --- Create directory structure ---
echo "Creating directories..."
mkdir -p "${BOT_CONFIG}/agents/main/agent"
mkdir -p "${BOT_CONFIG}/agents/main/sessions"
mkdir -p "${BOT_CONFIG}/canvas"
mkdir -p "${BOT_CONFIG}/credentials"
mkdir -p "${BOT_CONFIG}/cron"
mkdir -p "${BOT_CONFIG}/devices"
mkdir -p "${BOT_CONFIG}/identity"
mkdir -p "${BOT_CONFIG}/telegram"
mkdir -p "${BOT_WORKSPACE}"

# --- Write openclaw.json ---
echo "Writing openclaw.json..."
cat > "${BOT_CONFIG}/openclaw.json" <<OJSON
{
  "meta": {
    "lastTouchedVersion": "2026.1.30",
    "lastTouchedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  },
  "wizard": {
    "lastRunAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "lastRunVersion": "2026.1.30",
    "lastRunCommand": "onboard",
    "lastRunMode": "local"
  },
  "auth": {
    "profiles": {
      "anthropic:default": {
        "provider": "anthropic",
        "mode": "token"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-opus-4-5"
      },
      "models": {
        "anthropic/claude-opus-4-5": {}
      },
      "workspace": "/home/node/.openclaw/workspace",
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_BOT_TOKEN}"
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "${GATEWAY_TOKEN}"
    },
    "tailscale": {
      "mode": "off",
      "resetOnExit": false
    }
  },
  "plugins": {
    "entries": {
      "telegram": {
        "enabled": true
      }
    }
  }
}
OJSON

# --- Write auth-profiles.json ---
echo "Writing auth-profiles.json..."
cat > "${BOT_CONFIG}/agents/main/agent/auth-profiles.json" <<AJSON
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "type": "token",
      "provider": "anthropic",
      "token": "${ANTHROPIC_KEY}"
    }
  },
  "lastGood": {
    "anthropic": "anthropic:default"
  }
}
AJSON

# --- Write telegram-allowFrom.json (skip pairing!) ---
echo "Writing telegram-allowFrom.json..."
cat > "${BOT_CONFIG}/credentials/telegram-allowFrom.json" <<TJSON
{
  "version": 1,
  "allowFrom": [
    "${TELEGRAM_USER_ID}"
  ]
}
TJSON

# --- Write empty telegram-pairing.json ---
cat > "${BOT_CONFIG}/credentials/telegram-pairing.json" <<PJSON
{
  "version": 1,
  "requests": []
}
PJSON

# --- Write sessions.json ---
cat > "${BOT_CONFIG}/agents/main/sessions/sessions.json" <<SJSON
{
  "version": 1,
  "sessions": []
}
SJSON

# --- Find next available port ---
echo "Finding next available port..."
LAST_PORT=18799
if [ -f "$COMPOSE_OVERRIDE" ]; then
    FOUND_PORT=$(grep -oP '"(\d+):18789"' "$COMPOSE_OVERRIDE" "$COMPOSE_MAIN" 2>/dev/null | grep -oP '\d+(?=:18789)' | sort -n | tail -1)
    if [ -n "$FOUND_PORT" ]; then
        LAST_PORT=$FOUND_PORT
    fi
fi
NEXT_PORT=$((LAST_PORT + 1))
echo "  Assigned port: ${NEXT_PORT}"

# --- Check if services already in docker-compose.override.yml ---
if grep -q "container_name: ${BOT_NAME}$" "$COMPOSE_OVERRIDE" 2>/dev/null; then
    echo "Docker Compose services already exist in override file, skipping..."
else
    echo "Adding services to docker-compose.override.yml..."
    cat >> "$COMPOSE_OVERRIDE" <<DYML

  ${BOT_NAME}:
    image: openclaw:local
    container_name: ${BOT_NAME}
    restart: unless-stopped
    user: "1000:1000"
    environment:
      HOME: /home/node
      TERM: xterm-256color
    volumes:
      - ~/.clawdpods/${BOT_NAME}:/home/node/.openclaw:rw
      - ~/clawdpods-workspaces/${BOT_NAME}:/home/node/.openclaw/workspace:rw
      - ~/.gemini:/home/node/.gemini:ro
      - ~/.claude:/home/node/.claude:ro
    ports:
      - "${NEXT_PORT}:18789"
    init: true
    command: ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789"]

  ${BOT_NAME}-cli:
    image: openclaw:local
    container_name: ${BOT_NAME}-cli
    user: "1000:1000"
    environment:
      HOME: /home/node
      TERM: xterm-256color
      BROWSER: echo
    volumes:
      - ~/.clawdpods/${BOT_NAME}:/home/node/.openclaw:rw
      - ~/clawdpods-workspaces/${BOT_NAME}:/home/node/.openclaw/workspace:rw
      - ~/.gemini:/home/node/.gemini:ro
      - ~/.claude:/home/node/.claude:ro
    stdin_open: true
    tty: true
    init: true
    entrypoint: ["node", "dist/index.js"]
    profiles: ["cli"]
DYML
fi

# --- Set permissions ---
chmod 600 "${BOT_CONFIG}/openclaw.json"
chmod 700 "${BOT_CONFIG}/agents" "${BOT_CONFIG}/agents/main" "${BOT_CONFIG}/agents/main/agent"
chmod 600 "${BOT_CONFIG}/agents/main/agent/auth-profiles.json"
chmod 700 "${BOT_CONFIG}/credentials"
chmod 600 "${BOT_CONFIG}/credentials/telegram-allowFrom.json"
chmod 600 "${BOT_CONFIG}/credentials/telegram-pairing.json"

echo ""
echo "=== Bot '${BOT_NAME}' is ready! ==="
echo ""
echo "Start it with:"
echo "  docker compose up -d ${BOT_NAME}"
echo ""
echo "The bot is pre-configured with:"
echo "  - Anthropic API key (copied from father-bot)"
echo "  - Telegram bot token"
echo "  - Your Telegram user ID (no pairing needed)"
echo "  - Port ${NEXT_PORT}"
echo ""
echo "You can message it on Telegram immediately after starting."
