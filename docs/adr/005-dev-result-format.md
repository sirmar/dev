# ADR 005: Dev result format and narrowing concept

**Status:** Accepted  
**Date:** 2026-05-09

## Context

When an AI agent runs `dev unit`, it receives human-readable test output designed for terminal display. The agent has no reliable inter-run state: it cannot know which tests failed in the previous run without re-parsing prose output, and it cannot construct a runner-specific re-run argument without language-specific inference.

As the `dev` tool is increasingly used by AI agents (e.g. Claude Code), there is a need for a structured contract between the tool and the agent — one that survives across invocations without requiring the agent to parse or remember prose output.

## Decision

Introduce a **dev result format** — a minimal JSON file written to `out/<command>-result.json` after every command run. The file records only what an agent needs for inter-run decisions.

### Schema

```json
{
  "passed": true,
  "failures": [
    { "node_id": "<runner-native opaque string>" }
  ]
}
```

- `passed` (bool) — `true` if the command exited successfully, `false` otherwise.
- `failures` (array) — list of failure objects; empty when `passed` is `true`.
- `node_id` (string) — a runner-native value passed directly back to the runner to re-run a specific test. Opaque to the agent: it never constructs or interprets node IDs.

Human-readable failure detail (file, line, message, stack traces) remains in stdout only.

### File convention

`out/<command>-result.json` — e.g. `out/unit-result.json`. The `out/` directory is already created and mounted by `run_in()`.

### Node ID examples by runner

| Runner    | Example node_id                                                        |
|-----------|------------------------------------------------------------------------|
| pytest    | `src/tests/unit/test_auth.py::test_login_invalid`                      |
| vitest    | `src/tests/unit/auth.test.ts > AuthService > login invalid credentials` |
| shellspec | `spec/unit_spec.sh:42`                                                 |

vitest node IDs are derived from the JSON reporter output (`--reporter=json`), combining file path with the full nested describe/test name. shellspec node IDs use line numbers (`--line <n>`), which shellspec accepts directly as a re-run argument.

### Narrowing patterns

Two narrowing patterns activate automatically when `CLAUDECODE=1`:

**Node-ID-level narrowing (unit):** On entry, `cmd_unit` reads `out/unit-result.json`. If `failures[]` is non-empty, it passes the stored `node_id` values as positional arguments to the runner — scoping the run to previously failing tests only.

**Stage-level narrowing (check):** On entry, `cmd_check` reads `out/check-result.json`. If `failures[]` is non-empty, it runs only the stages listed in `failures[].node_id` rather than the full pipeline.

### Reset rule

The scope returns to a full run automatically once all failures are resolved: when the result file has `failures[]` empty (or the file is absent), the next run uses the full suite. No explicit `--all` flag is needed.

### JSON re-emit

When `CLAUDECODE=1`, the result JSON is re-emitted as the final stdout line after the run completes. This allows the agent to read the result inline from the Bash tool output without a separate file-read call.

### Always-written

The result file is written after every run regardless of who invoked the command (`CLAUDECODE=1` or not). CI pipelines and editor tooling can consume it without special flags.

### Implementation modules

- **Per-image normalizer scripts** (`images/<lang>/scripts/unit-normalizer`) — convert the runner's native output to the common schema. Pure input/output; testable in isolation without Docker.
- **Unit entrypoint updates** — pass structured output flags to the runner and call the normalizer after exit.
- **`cmd_unit` in `dev.sh`** — reads result file on entry for narrowing; re-emits JSON on exit when `CLAUDECODE=1`.
- **`cmd_unit` in `mdev.sh`** — aggregates per-service result files into a workspace-level result with a `services` array.

## Consequences

- Every `dev unit` run writes `out/unit-result.json`; agents and tooling can rely on it unconditionally.
- Narrowing reduces context consumption for agents by scoping re-runs to failing tests only.
- The `node_id` abstraction shields agents from runner-specific argument syntax.
- The schema is intentionally minimal; additional fields (`counts`, `duration_s`, message detail) are deliberately excluded and remain in stdout.
- The same schema and file convention extends naturally to `lint`, `types`, `security`, and `build` — implementation for those commands is deferred.
- Normalizer scripts are separate from entrypoints, enabling isolated testing of the conversion logic.
