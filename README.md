# dev

A language-agnostic developer lifecycle CLI that provides a unified interface for building, testing, releasing, and deploying projects via Docker.

## How it works

`dev` discovers the project root by walking up the directory tree until it finds a `.dev` config file. All commands run inside Docker containers — there is no assumption about the language or toolchain. The Dockerfile in each project defines the stages (`lint`, `unit`, `prod`, etc.), and `dev` builds and runs the appropriate stage for each command.

## Installation

Clone the repo and run the install script:

```sh
git clone <repo-url>
cd dev
./scripts/install.sh
```

This creates a symlink at `~/.local/bin/dev` pointing to `app/dev.sh`, installs shell completions, and creates a user config file at `~/.config/dev/config`. Make sure `~/.local/bin` is in your `PATH`.

### User config

To enable `dev login` and `dev push`, set these in `~/.config/dev/config`:

```sh
DEV_REGISTRY=ghcr.io/your-org
DEV_REGISTRY_USER=your-username
DEV_REGISTRY_TOKEN=your-token
```

If you are authenticated via the `gh` CLI, `dev` will use it automatically and you can omit `DEV_REGISTRY_USER` and `DEV_REGISTRY_TOKEN`.

## Project config

Each project needs a `.dev` file at its root:

```sh
DEV_NAME=my-app
DEV_REPO_TYPE=service   # service (default) or image
```

Available config keys:

| Key                 | Description                                |
|---------------------|--------------------------------------------|
| `DEV_NAME`          | **Required.** Project name, used for image/container names |
| `DEV_REPO_TYPE`     | **Required.** `service`, `tool`, or `image` |
| `DEV_CONTEXT`       | Docker build context                       |
| `DEV_NETWORK`       | External Docker network to attach to       |
| `DEV_SCRIPTS`       | Named scripts for `dev exec`, e.g. `evaluate:scripts/evaluate.py` |
| `DEV_DB_NAME`       | Database name for `db-shell`/`db-migrate`  |
| `DEV_DB_USER`       | Database user                              |
| `DEV_DB_PASSWORD`   | Database password                          |

## Commands

```
dev <command> [args]
```

See [COMMANDS.md](COMMANDS.md) for the full command reference.

## Dockerfile conventions

Each project's `Dockerfile` uses named stages that map to `dev` commands:

```dockerfile
FROM base AS lint
FROM base AS unit
FROM base AS coverage
FROM base AS prod
```

`dev` only runs stages that exist — unknown or missing stages are skipped gracefully.

## Base images

Reusable base images for common languages live in `images/<language>/`. Each has a `Dockerfile`, entrypoint scripts for lint and format, and its own `.dev` config. These images are built and released with `dev` itself, and referenced in downstream project Dockerfiles.

## Development

`dev` uses itself for its own development.

```sh
dev check      # format + lint + types + coverage
dev unit       # unit tests only
dev e2e        # e2e tests
```

The project's own `Dockerfile` and `.dev` config define the tooling. The stack is Bash, tested with ShellSpec, linted with ShellCheck, and formatted with shfmt.
