FROM node:22-slim
LABEL org.opencontainers.image.source=https://github.com/sirmar/dev
RUN npm install -g pnpm@10.33.0
WORKDIR /workspace
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*-entrypoint.sh
