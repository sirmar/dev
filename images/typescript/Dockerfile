FROM node:22-slim
RUN npm install -g pnpm@10.33.0
WORKDIR /workspace
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*-entrypoint.sh
