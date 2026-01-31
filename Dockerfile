FROM openclaw:local

USER root
RUN npm install -g @google/gemini-cli @anthropic-ai/claude-code
USER node
