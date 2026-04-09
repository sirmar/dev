FROM python:3.14-slim
WORKDIR /workspace
ENV UV_PROJECT_ENVIRONMENT=/venv
ENV PATH="/venv/bin:$PATH"
COPY --from=ghcr.io/astral-sh/uv:0.11.5 /uv /usr/local/bin/uv
COPY scripts/lint-entrypoint.sh /usr/local/bin/lint-entrypoint.sh
COPY scripts/format-entrypoint.sh /usr/local/bin/format-entrypoint.sh
RUN chmod +x /usr/local/bin/lint-entrypoint.sh /usr/local/bin/format-entrypoint.sh
