# dev

## Commands

Full reference: [COMMANDS.md](COMMANDS.md)

## Code Style

- `dev.sh` is language-agnostic — no language/toolchain logic here.
- Language-specific logic (lint, unit, coverage etc.) belongs in Dockerfile entrypoints, Compose files, or `.dev` config.

## Base Images

Images live in `images/<language>/`. Follow the existing structure when adding new images.

## Completions

- Keep `completions/dev.bash` and `completions/_dev` in sync when adding/removing commands.

## Workflow

- Don't run shellspec/shellcheck/shfmt directly — hooks handle this.
- Add or update tests when changing implementation.
