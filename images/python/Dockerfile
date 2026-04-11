FROM python:3.14-slim
WORKDIR /workspace
ENV UV_PROJECT_ENVIRONMENT=/venv
ENV PATH="/venv/bin:$PATH"
COPY --from=ghcr.io/astral-sh/uv:0.11.5 /uv /usr/local/bin/uv
ENV PYTHONPATH=/workspace/src
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*-entrypoint.sh
