---
name: new-bot
description: Create a new isolated OpenClaw bot with its own config and workspace directories
disable-model-invocation: true
allowed-tools: Bash(mkdir:*), Read, Edit, Write
argument-hint: <bot-name>
---

# Create a new OpenClaw bot

Create a new isolated bot named `$ARGUMENTS`.

## Context

- Override file location: `docker-compose.override.yml` (new bots go here to keep them private)
- Existing bots: !`ls -1 ~/.clawdpods/ 2>/dev/null || echo "None"`
- Last used port (checking both files): !`grep -ohP '"\K[0-9]+(?=:18789")' docker-compose.yml docker-compose.override.yml 2>/dev/null | sort -n | tail -1 || echo "18799"`

## Steps

1. **Validate the bot name** - must be lowercase alphanumeric with hyphens only

2. **Create directories**:
   ```bash
   mkdir -p ~/.clawdpods/$ARGUMENTS
   mkdir -p ~/$ARGUMENTS-workspace
   ```

3. **Check if `docker-compose.override.yml` exists**. If not, create it with this header:
   ```yaml
   # Personal bot configurations - this file is gitignored
   # Docker Compose automatically merges this with docker-compose.yml

   services:
   ```

4. **Add services to `docker-compose.override.yml`** - use port = last used port + 1. Add BOTH gateway and CLI services:

   ```yaml
     $ARGUMENTS:
       image: openclaw:local
       container_name: $ARGUMENTS
       restart: unless-stopped
       user: "1000:1000"
       environment:
         HOME: /home/node
         TERM: xterm-256color
       volumes:
         - ~/.clawdpods/$ARGUMENTS:/home/node/.openclaw:rw
         - ~/$ARGUMENTS-workspace:/home/node/.openclaw/workspace:rw
         - ~/.gemini:/home/node/.gemini:ro
         - ~/.claude:/home/node/.claude:ro
       ports:
         - "<next-port>:18789"
       init: true
       command: ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789"]

     $ARGUMENTS-cli:
       image: openclaw:local
       container_name: $ARGUMENTS-cli
       user: "1000:1000"
       environment:
         HOME: /home/node
         TERM: xterm-256color
         BROWSER: echo
       volumes:
         - ~/.clawdpods/$ARGUMENTS:/home/node/.openclaw:rw
         - ~/$ARGUMENTS-workspace:/home/node/.openclaw/workspace:rw
         - ~/.gemini:/home/node/.gemini:ro
         - ~/.claude:/home/node/.claude:ro
       stdin_open: true
       tty: true
       init: true
       entrypoint: ["node", "dist/index.js"]
       profiles: ["cli"]
   ```

5. **Report success** with next steps:
   - Run onboarding: `docker compose run --rm -it $ARGUMENTS-cli onboard`
   - Start the bot: `docker compose up -d $ARGUMENTS`
   - Approve Telegram pairing: `docker compose run --rm $ARGUMENTS-cli pairing approve telegram <code>`

Do not run onboarding or start the container.
