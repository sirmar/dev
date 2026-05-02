# ADR 004: Shell completions are generated, not hand-maintained

**Status:** Accepted  
**Date:** 2026-05-02

## Context

Bash and zsh completion files need to know the full command list, which commands take static arguments, and which repo types support which commands. Maintaining these files by hand meant they lagged behind changes to the command registry and were a recurring source of subtle inconsistencies.

## Decision

`src/generate-completions.sh` generates `completions/dev.bash`, `completions/_dev`, `completions/mdev.bash`, and `completions/_mdev` by sourcing `dev.sh` and `mdev.sh` directly and iterating `_DEV_COMMANDS` / `MDEV_COMMANDS`. The generated files are committed to the repository so users can install completions without running the generator.

The generator is invoked automatically via a pre-commit hook. The output files must never be edited by hand.

Dynamic completion behaviour that cannot be derived from the registry (file arguments, service names from Compose files, `exec` script names from `.dev`) is emitted as static shell fragments within the generator itself.

## Consequences

- Any change to the command registry that should affect completions requires re-running `src/generate-completions.sh` and committing the result — the pre-commit hook enforces this.
- New static arguments for a command are added to `cmd_args` in `dev.sh`; the generator picks them up automatically.
- New dynamic completion behaviour (e.g. a new argument type) requires a corresponding fragment in the generator script.
