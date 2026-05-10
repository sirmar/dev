# ADR 009: Stage existence as opt-in feature flag

**Status:** Accepted  
**Date:** 2026-04-07 (initial commit)

## Context

`dev` defines a set of canonical stage names (`lint`, `format`, `unit`, `types`, `security`, `coverage`, `lock`, `watch`, `scripts`, `prod`, `e2e`). Not every project needs every stage — a library has no `prod` stage; a simple tool may not need `security` scanning; a project may not yet have a `coverage` stage.

Two options for handling missing stages:
1. Treat a missing stage as an error — projects must explicitly disable commands they don't use.
2. Treat a missing stage as a skip — projects opt into features by adding stages.

## Decision

`has_dockerfile_stage` inspects the project Dockerfile before every stage-based command. If the named stage does not exist, `run_stage` and `run_stage_compose` print an info message (`no '<stage>' stage found in Dockerfile — skipping`) and return successfully (exit 0).

The Dockerfile is the feature manifest: adding a stage enables the corresponding `dev` command; removing it disables it. No `.dev` flags, no explicit opt-out list.

The same principle applies to `dev exec`: if the `scripts` stage is absent, the command skips.

## Consequences

- Projects start with a minimal Dockerfile and grow features incrementally.
- `dev check` and `dev ci` naturally adapt to the project's Dockerfile without configuration — they only run stages that exist.
- A typo in a stage name silently skips instead of erroring, which can mask mistakes. By convention, stage names are validated against the canonical list in CONTEXT.md.
- Removing a stage from a Dockerfile is a safe operation — no other config needs updating.
