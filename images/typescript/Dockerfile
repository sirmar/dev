FROM node:22-slim
LABEL org.opencontainers.image.source=https://github.com/sirmar/dev
RUN apt-get update && apt-get install -y --no-install-recommends jq=1.6-2.1+deb12u1 && rm -rf /var/lib/apt/lists/*
RUN npm install -g pnpm@10.33.2
WORKDIR /workspace
COPY typescript/scripts/ /usr/local/bin/
COPY shared/scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*-entrypoint.sh
