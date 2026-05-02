# ADR 003: Composite commands delegate to `run_stage`

**Status:** Accepted  
**Date:** 2026-05-02

## Context

Several `dev` commands (`lint`, `unit`, `types`, `security`, `watch`, `run`, …) follow the same three-step pattern: check that the Dockerfile stage exists, build the image quietly, then run a container. Before this decision, some commands (notably `cmd_watch` and `cmd_run`) inlined their own copies of this logic, meaning that changes to build flags or TTY handling had to be applied in multiple places, and the behaviour was not guaranteed to be consistent.

## Decision

`run_stage <stage> <label> [args…]` is the universal helper for all stage-based commands:

1. Returns early (with an info message) if the named stage does not exist in the Dockerfile.
2. Calls `build_image <stage> quiet=true`.
3. Calls `run_in <stage> [args…]`.

Every command that runs inside a Dockerfile stage — `cmd_lint`, `cmd_format`, `cmd_unit`, `cmd_types`, `cmd_security`, `cmd_lock`, `cmd_watch`, `cmd_run` (non-e2e path) — delegates to `run_stage`. Composite commands (`cmd_check`, `cmd_ci`) delegate to these single-stage commands, never to `run_stage` directly.

Commands that run a stage inside a Docker Compose environment use a parallel helper:

`run_stage_compose <stage> <label> <compose_fn> <compose_file> [required|optional]`

1. Returns early if the named stage does not exist in the Dockerfile.
2. If the compose file is absent and the mode is `required`, returns early. If `optional`, falls back to `run_in`.
3. Tears down any existing compose environment (`compose_fn down -v`).
4. Calls `build_image <stage> quiet=true`.
5. Calls `run_compose_suite <compose_fn> <stage>`.

`cmd_coverage` uses `optional` (compose is needed when services are required for coverage, but falls back to direct Docker otherwise). `cmd_e2e` uses `required` (e2e tests by definition need the compose services).

## Consequences

- Changes to build flags, teardown semantics, or CI log behaviour propagate to all stage-based commands automatically.
- New stage-based commands are a one-liner via `run_stage` or `run_stage_compose`.
- `cmd_run` for e2e repos does not use either helper — it runs the compose suite without building a stage image, since the compose file manages its own images.
