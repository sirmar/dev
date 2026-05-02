# ADR 002: `find_dev_file` as the canonical config reader

**Status:** Accepted  
**Date:** 2026-05-02

## Context

The `.dev` file is a shell script that declares a project's identity and configuration. Before this decision, it was read in at least four different ways across the codebase: sourced in full, grepped with `grep+cut`, parsed with `grep+sed`, and read directly. Each approach was subtly different in what it exposed and how it handled missing keys, making it hard to reason about config access and easy to introduce inconsistencies.

## Decision

`find_dev_file` is the single entry point for locating a `.dev` file. It walks up from the current directory, sets `ROOT_DIR`, and returns. `load_config` then sources the file (and the optional user config at `~/.config/dev/config`) and exports all known variables with defaults applied.

No code outside of these two functions reads or parses `.dev` directly. In `cmd_completions`, where a full `load_config` would be unsafe (no guaranteed `ROOT_DIR`), `find_dev_file` is still called first, and only then is the file sourced in a controlled scope.

`mdev` needs to read individual service `.dev` files without entering each service directory. It does so via `read_dev_var`, which sources the `.dev` file in an isolated subshell: `(source "$MDEV_ROOT/$service/.dev" && eval "echo \"\${VAR:-}\"")`. This preserves the invariant — no `grep`/`sed` parsing — while avoiding the need to `cd` into each service.

## Consequences

- Config access is predictable: either `ROOT_DIR` is set and the full config is loaded, or it isn't and the command fails with a clear error.
- Adding a new `.dev` variable means updating `load_config` once; no other read sites to update.
- The pattern requires that `.dev` remain a valid shell script (not a key=value ini file). This is an existing constraint and is preserved.
