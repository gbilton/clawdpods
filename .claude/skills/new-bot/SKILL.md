---
name: new-bot
description: Create a new isolated OpenClaw bot with its own config and workspace directories
disable-model-invocation: true
allowed-tools: Bash(mkdir:*), Read, Edit
argument-hint: <bot-name>
---

# Create a new OpenClaw bot

Create a new isolated bot named `$ARGUMENTS`.

## Context

- Docker compose file location: `/home/gbilton/clawdpods/docker-compose.yml`
- Existing bots: !`ls -1 ~/.clawdpods/ 2>/dev/null || echo "None"`
- Last used port: !`grep -oP '"\K[0-9]+(?=:18789")' /home/gbilton/clawdpods/docker-compose.yml 2>/dev/null | sort -n | tail -1 || echo "18799"`

## Steps

1. **Validate the bot name** - must be lowercase alphanumeric with hyphens only

2. **Create directories**:
   ```bash
   mkdir -p ~/.clawdpods/$ARGUMENTS
   mkdir -p ~/$ARGUMENTS-workspace
   ```

3. **Add services to docker-compose.yml** - use port = last used port + 1. Add BOTH gateway and CLI services:

   ```yaml
     $ARGUMENTS:
       image: openclaw:local
       container_name: $ARGUMENTS
       restart: unless-stopped
       environment:
         HOME: /home/node
         TERM: xterm-256color
       volumes:
         - ~/.clawdpods/$ARGUMENTS:/home/node/.openclaw:rw
         - ~/$ARGUMENTS-workspace:/home/node/.openclaw/workspace:rw
       ports:
         - "<next-port>:18789"
       init: true
       command: ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789"]

     $ARGUMENTS-cli:
       image: openclaw:local
       container_name: $ARGUMENTS-cli
       environment:
         HOME: /home/node
         TERM: xterm-256color
         BROWSER: echo
       volumes:
         - ~/.clawdpods/$ARGUMENTS:/home/node/.openclaw:rw
         - ~/$ARGUMENTS-workspace:/home/node/.openclaw/workspace:rw
       stdin_open: true
       tty: true
       init: true
       entrypoint: ["node", "dist/index.js"]
       profiles: ["cli"]
   ```

4. **Report success** with next steps:
   - Run onboarding: `docker compose run --rm -it $ARGUMENTS-cli onboard`
   - Start the bot: `docker compose up -d $ARGUMENTS`
   - Approve Telegram pairing: `docker compose run --rm $ARGUMENTS-cli pairing approve telegram <code>`

Do not run onboarding or start the container.
