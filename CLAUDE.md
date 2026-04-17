# dev

## Commands

Full reference: [docs/dev-commands.md](docs/dev-commands.md) · [docs/mdev-commands.md](docs/mdev-commands.md)

## Code Style

- `dev.sh` is language-agnostic — no language/toolchain logic here.
- Language-specific logic (lint, unit, coverage etc.) belongs in Dockerfile entrypoints, Compose files, or `.dev` config.

## Base Images

Images live in `images/<language>/`. Follow the existing structure when adding new images.

## Completions

- Keep `completions/dev.bash` and `completions/_dev` in sync when adding/removing `dev` commands.
- Keep `completions/mdev.bash` and `completions/_mdev` in sync when adding/removing `mdev` commands.

## Workflow

- Don't run shellspec/shellcheck/shfmt directly — hooks handle this.
- Add or update tests when changing implementation.
