# ADR 010: e2e tests run on an isolated Docker network

**Status:** Accepted  
**Date:** 2026-04-14 (`f3b5622 Add e2e command with isolated compose network and derived env vars`)

## Context

A service repo has two distinct Compose environments: the development environment (`docker-compose.yml`, brought up with `dev up`) and the e2e test suite (`docker-compose.e2e.yml`, run with `dev e2e`). Both environments may include a database container and an application container. If they share a Docker network and container names, they conflict — ports collide, containers shadow each other, and running e2e tests while the dev environment is up produces unpredictable results.

## Decision

The e2e Compose environment runs on a dedicated Docker network: `DEV_E2E_NETWORK` (`$DEV_NAME-e2e`). This network is separate from both the default Compose network and `DEV_NETWORK` used by the dev environment.

All e2e containers use distinct derived names (`DEV_E2E_CONTAINER`, `DEV_E2E_DB_CONTAINER`) so they never collide with their dev-environment counterparts.

`run_compose_suite` for e2e tears down the e2e environment (`compose_e2e down -v`) before each run, ensuring a clean state regardless of prior runs. The dev environment (`dev up`) is unaffected.

## Consequences

- `dev e2e` can run safely while `dev up` is running — the two environments are fully isolated at the network level.
- The e2e network is ephemeral: created on `dev e2e`, torn down after the run.
- Compose files for e2e must use `DEV_E2E_NETWORK` (injected as an env var) rather than hardcoding a network name.
- Port conflicts between dev and e2e environments are impossible by design.
