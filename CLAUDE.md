# dev

A language-agnostic developer lifecycle CLI that provides a unified interface for building, testing, releasing, and deploying projects via Docker.

## Overview

- Subcommand interface: `dev <command> [args]`
- Discovers the project root by walking up the directory tree for a `.dev` config file
- All services and tooling run in Docker containers (Docker Compose + multi-stage Dockerfiles)
- Replaces per-project Makefiles with a single shared tool

## Stack

- **Language:** Bash
- **Linting:** ShellCheck
- **Testing:** ShellSpec
- **Formatting:** shfmt

## Commands

See [COMMANDS.md](COMMANDS.md) for the full command reference.

## Code Style

- `dev.sh` must stay language-agnostic — it orchestrates commands without knowing the language or toolchain.
- Language-specific logic (what to lint, how to test) belongs in Dockerfile entrypoint scripts, Compose files, or the project's `.dev` config file.

## Base Images

Reusable Docker base images live in `images/<language>/`. Each image:

- Has a `Dockerfile` with language tooling pre-installed
- Has `scripts/lint-entrypoint.sh` and `scripts/format-entrypoint.sh`
- Has a `.dev` config with `DEV_REPO_TYPE=image`

When adding a new language image, follow this same structure.

## Completions

- When adding or removing commands, update both `completions/dev.bash` and `completions/_dev` to match.

## Dogfooding

`dev` uses itself for its own development. The root `.dev` config and `Dockerfile` define the tooling used to lint, test, and format the project.

## Workflow

- Never run tests, lint, or format commands (shellspec, shellcheck, shfmt). Hooks will handle this.
- When changing implementation, add or update tests to cover the changes.
