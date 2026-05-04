FROM python:3.14-slim
LABEL org.opencontainers.image.source=https://github.com/sirmar/dev
RUN apt-get update && apt-get install -y --no-install-recommends jq=1.7.1-6+deb13u1 && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
ENV UV_PROJECT_ENVIRONMENT=/venv
ENV PATH="/venv/bin:$PATH"
COPY --from=ghcr.io/astral-sh/uv:0.11.5 /uv /usr/local/bin/uv
ENV PYTHONPATH=/workspace/src
COPY python/scripts/ /usr/local/bin/
COPY shared/scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*-entrypoint.sh /usr/local/bin/healthcheck.sh
