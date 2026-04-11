FROM nginx:1.28-alpine
LABEL org.opencontainers.image.source=https://github.com/sirmar/dev
COPY scripts/serve-entrypoint.sh /usr/local/bin/serve-entrypoint.sh
RUN chmod +x /usr/local/bin/serve-entrypoint.sh
