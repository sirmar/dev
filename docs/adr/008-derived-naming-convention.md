# ADR 008: All container and image names derived from DEV_NAME

**Status:** Accepted  
**Date:** 2026-04-07 (initial commit; extended when e2e was added)

## Context

A single project can have multiple Docker images and containers running simultaneously: a development service, an e2e test suite, a database, a coverage runner. Each needs a stable, unique name for Docker to manage. Without a convention, projects would manually declare every container name in `.dev`, creating redundancy and the risk of name collisions between projects.

## Decision

All image and container names are derived deterministically from `DEV_NAME` — the single required identity field in `.dev`. The derivation is applied by `load_config` in `dev.sh`:

| Variable | Value |
|---|---|
| `DEV_IMAGE` | `$DEV_NAME` |
| `DEV_CONTAINER` | `$DEV_NAME` |
| `DEV_DB_CONTAINER` | `$DEV_NAME-db` |
| `DEV_E2E_IMAGE` | `$DEV_NAME-e2e` |
| `DEV_E2E_CONTAINER` | `$DEV_NAME-e2e` |
| `DEV_E2E_DB_CONTAINER` | `$DEV_NAME-db-e2e` |
| `DEV_E2E_NETWORK` | `$DEV_NAME-e2e` |
| `DEV_COVERAGE_IMAGE` | `$DEV_NAME-coverage` |
| `DEV_COVERAGE_CONTAINER` | `$DEV_NAME-coverage` |

Projects never set these derived variables — they are read-only outputs of `load_config`.

## Consequences

- Projects only need to set `DEV_NAME`; all container and image names follow automatically.
- Name uniqueness across projects is the project author's responsibility via a unique `DEV_NAME`.
- Scripts and Compose files that reference container names must use the exported variables, not hardcoded strings.
- Renaming a project (`DEV_NAME`) changes all derived names and may require Docker cleanup.
