FROM node:20-slim

RUN corepack enable && corepack prepare yarn@stable --activate
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace
ENTRYPOINT ["claude"]
