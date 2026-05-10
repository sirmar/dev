# ADR 006: Language-agnostic core — all toolchain logic in Docker

**Status:** Accepted  
**Date:** 2026-04-07 (initial commit)

## Context

A developer lifecycle CLI needs to support lint, test, format, type-check, and security scanning across multiple languages. The naive approach is to branch on language inside the CLI itself — detect Python, run `uv`; detect Node, run `pnpm`; etc. This creates a tight coupling between the CLI and every supported toolchain, making each new language an update to the shell scripts and a new surface for version conflicts on the host.

## Decision

`dev.sh` contains no language or toolchain logic. All language-specific behaviour — which linter to run, how to invoke the test runner, how to install dependencies — lives inside Dockerfile stages and Compose files.

`dev.sh` only knows how to build a named Docker stage and run a container from it. The contract with a project is: provide a Dockerfile with the expected stage names (`lint`, `unit`, `types`, etc.) and `dev` will build and run them. What those stages do internally is entirely up to the project.

## Consequences

- Adding support for a new language requires no changes to `dev.sh` — only a new base image and project Dockerfile convention.
- Host machines need only Docker, not any language runtime.
- Toolchain versions are pinned per-project in the Dockerfile, not globally on the host.
- The CLI's test surface is limited to Docker orchestration logic; language-specific behaviour is tested inside Docker.
- Projects must author a Dockerfile; there is no zero-config path for trivial projects.
