# Migrating a Project to `dev`

### 1. `.dev` — Project Config

Place this at the repo root. Only set what you need:

```sh
DEV_NAME=myapp          # used for image names and compose project name
DEV_SHELL=bash          # shell used by `dev shell` (default: sh)
DEV_NETWORK=mynetwork   # optional: external Docker network to attach to

# Optional: database config for `dev db-shell` and `dev db-migrate`
DEV_DB_NAME=mydb
DEV_DB_USER=root
DEV_DB_PASSWORD=secret
```

---

### 2. `Dockerfile` — Multi-stage

Each `dev` command maps to a named stage. Only include the stages your project needs. The stage name determines which command activates it — `dev lint` uses `lint`, `dev unit` uses `unit`, etc. Stages that don't exist are silently skipped.

```dockerfile
# Shared base
FROM python:3.12-slim AS base
WORKDIR /workspace

# dev build / dev shell / dev run
FROM base AS app
COPY . .
RUN pip install -e .
ENTRYPOINT ["python"]

# dev lint [file]
FROM base AS lint
RUN pip install ruff
COPY scripts/lint-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# dev format [file]
FROM base AS format
RUN pip install ruff
COPY scripts/format-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# dev unit
FROM base AS unit
RUN pip install pytest
COPY . .
ENTRYPOINT ["pytest"]

# dev coverage
FROM base AS coverage
RUN pip install pytest pytest-cov
COPY . .
ENTRYPOINT ["pytest", "--cov=src", "--cov-report=term"]

# dev types
FROM base AS types
RUN pip install mypy
COPY . .
ENTRYPOINT ["mypy", "src"]
```

#### Using the prebuilt Python base image

`ghcr.io/sirmar/dev-python` provides python, uv, and the lint/format entrypoint scripts. Use it as your `base` stage and introduce a `deps` stage for dependency installation. All other stages extend from `deps`.

```dockerfile
FROM ghcr.io/sirmar/dev-python:v0.1.0 AS base

FROM base AS deps
COPY backend/pyproject.toml backend/uv.lock ./
COPY shared/ /shared/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --extra dev

FROM deps AS app
ENTRYPOINT ["uv", "run"]

FROM deps AS lint
ENTRYPOINT ["/usr/local/bin/lint-entrypoint.sh"]

FROM deps AS format
ENTRYPOINT ["/usr/local/bin/format-entrypoint.sh"]

FROM deps AS unit
ENTRYPOINT ["pytest", "-q", "tests/unit/"]

FROM deps AS coverage
ENTRYPOINT ["pytest", "-q", "--cov=app", "--cov-report=term", "tests/unit/"]

FROM deps AS types
ENTRYPOINT ["ty", "check", "app/"]

FROM base AS prod
COPY backend/pyproject.toml backend/uv.lock ./
COPY shared/ /shared/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --no-dev
COPY backend/app/ app/
COPY backend/migrations/ migrations/
EXPOSE 8000
CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Source files are always volume-mounted at `/workspace` when `dev` runs a container.

**Entrypoint scripts** for `lint` and `format` stages should handle two cases:
- Called with a file argument → run the tool on that file only
- Called with no arguments → scan the whole workspace

```sh
# scripts/lint-entrypoint.sh
#!/bin/sh
if [ $# -gt 0 ]; then
    exec ruff check "$@"
fi
exec ruff check /workspace
```

```sh
# scripts/format-entrypoint.sh
#!/bin/sh
if [ $# -gt 0 ]; then
    exec ruff format "$@"
fi
exec ruff format /workspace
```

---

### 3. `docker-compose.yml` — Services

Used by `dev up` / `dev down`. The compose file lives at the repo root and uses the `app` stage as the main service image.

```yaml
services:
  app:
    image: myapp                    # matches DEV_NAME
    build:
      context: .
      target: app
    volumes:
      - .:/workspace
    ports:
      - "8080:8080"
    depends_on:
      - db

  db:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: mydb
    ports:
      - "3306:3306"

networks:
  default:
    name: mynetwork                 # matches DEV_NETWORK if set
```

---

### Stage → Command Reference

| Stage in Dockerfile | `dev` command | Required? |
|---|---|---|
| `app` | `dev build`, `dev shell`, `dev run` | Yes |
| `lint` | `dev lint [file]` | No |
| `format` | `dev format [file]` | No |
| `unit` | `dev unit` | No |
| `coverage` | `dev coverage` | No |
| `types` | `dev types` | No |

All tool-specific logic (what files to lint, how to run tests) belongs in the Dockerfile entrypoint scripts — **not** in `dev.sh`.
