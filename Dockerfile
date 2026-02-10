# Build stage - clone and build OpenClaw
FROM node:22-bookworm AS builder

RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable

WORKDIR /app
RUN git clone --depth 1 https://github.com/openclaw/openclaw.git .

RUN pnpm install --frozen-lockfile
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# Final image
FROM node:22-bookworm-slim

# Install curl, git, ssh and cron
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    git \
    curl \
    openssh-client \
    cron \
 && rm -rf /var/lib/apt/lists/*

RUN corepack enable
RUN npm install -g @google/gemini-cli @anthropic-ai/claude-code

WORKDIR /app
COPY --from=builder /app /app

ENV NODE_ENV=production

# Create .ssh directory for SSH key mounts
RUN mkdir -p /home/node/.ssh && chown node:node /home/node/.ssh && chmod 700 /home/node/.ssh

USER node

CMD ["node", "dist/index.js"]
