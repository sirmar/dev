---
name: migrate-to-dev
description: Migrate an existing repo to use the dev CLI tool, or complete an incomplete dev setup. Detects language and repo type, then runs dev init which skips existing files and logs what it writes vs skips. Use when a repo lacks .dev, Dockerfile, or has an incomplete dev tool setup.
tools: Read, Glob, Grep, Bash
---

# migrate-to-dev

Migrate an existing repo to use the `dev` CLI tool, or complete an incomplete setup.

`dev init` is idempotent — it skips files that already exist and logs each action. Use it for both fresh migrations and completing partial setups.

## Supported combinations

| Language | Repo type | Key indicators |
|----------|-----------|----------------|
| python | tool | pyproject.toml, no docker-compose.yml |
| python | service | pyproject.toml + docker-compose.yml |
| typescript | service | package.json + docker-compose.yml |
| bash | tool | .shellspec or only .sh files in src/ |
| (any) | image | minimal Dockerfile, no language files |

## Phase 1: Detect project state

```bash
ls -la .dev Dockerfile docker-compose.yml pyproject.toml package.json .shellspec 2>/dev/null
cat .dev 2>/dev/null
```

**Determine combination:**
- `pyproject.toml` + `docker-compose.yml` → **python/service**
- `pyproject.toml`, no compose → **python/tool**
- `package.json` + `docker-compose.yml` → **typescript/service**
- `.shellspec` or bash-only src/ → **bash/tool**
- No language files → **image**

## Phase 2: Clarify with user (if ambiguous)

- Repo type and language — if not clear from files
- DEV_NAME — suggest the directory name as default

## Phase 3: Run dev init

```bash
# For tool/service:
dev init <type> <language> <name>

# For image:
dev init image <name>
```

`dev init` will log each file as either `write <file>` (created) or `skip <file>` (already existed). Existing files are never overwritten.

## Phase 4: Handle incomplete .dev (if it existed before)

If `.dev` already existed, check that it contains both required keys:

```sh
DEV_NAME=<name>
DEV_REPO_TYPE=<tool|service|image>
```

Add any missing keys manually.

## Phase 5: Validate

```bash
dev build
dev check
```

Report failures with suggestions. Common issues:
- `pyproject.toml` missing dev dependencies (pytest, ruff, ty) → add `[project.optional-dependencies] dev = [...]`
- Lock file out of date → run `uv sync --extra dev` or `pnpm install`
- Missing entrypoint in prod stage → adapt the prod `ENTRYPOINT` to the actual app entry point
