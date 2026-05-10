# dev commands

| Command            | Description                               |
|--------------------|-------------------------------------------|
| `init <type> <lang> <name>` | Scaffold a new project              |
| `build`            | Build Docker image(s)                     |
| `lint [file...]`   | Lint source files or Dockerfiles          |
| `lint-dockerfile`  | Lint the Dockerfile                       |
| `format [file...]` | Format source files                       |
| `unit [file...]`   | Run unit tests                            |
| `unit --failed`    | Re-run only tests that failed in the last run |
| `e2e --failed`     | Re-run only e2e tests that failed in the last run |
| `check --failed`   | Re-run only check stages that failed in the last run |
| `coverage [file...]` | Run tests with coverage report          |
| `types`            | Run static type checking                  |
| `security`         | Run security scanning                     |
| `lock`             | Regenerate lock file                      |
| `check`            | Run lint-dockerfile, format, lint, types, security, unit, and e2e |
| `ci`               | Build and run full quality check          |
| `e2e`              | Run e2e tests                             |
| `watch`            | Run with hot reload                       |
| `shell`            | Open shell in running container           |
| `run [args]`       | Run the tool (tool repos only)            |
| `exec <script>`    | Run a named script in the scripts stage   |
| `rebuild`          | Build image(s) and start services         |
| `up [service...]`  | Start services via Docker Compose         |
| `down [args]`      | Stop services via Docker Compose          |
| `clean`            | Remove all containers and volumes         |
| `logs [-f] [svc]`  | Show service logs (use -f to follow)      |
| `db-shell`         | Enter shell in running database container |
| `db-migrate`       | Run database migrations                   |
| `login`            | Log in to container registry              |
| `push`             | Push image(s) to registry                 |
| `release <type>`   | Create release tag (major\|minor\|patch)  |
| `tag`              | Print the latest git tag                  |
| `diagnose [--repo-only]` | Check system and repo configuration (`--repo-only` skips system checks) |

## Result files

Every command that runs checks writes a result file to `out/` after each run, regardless of who triggered the run. These files give AI agents reliable inter-run state without re-parsing prose output.

### Commands with node-ID failures (`unit`, `e2e`)

```json
{
  "passed": false,
  "failures": [
    { "node_id": "<runner-native test identifier>" }
  ]
}
```

- `passed` — `true` if the command exited 0, `false` otherwise
- `failures` — list of failing tests; empty when all tests pass
- `node_id` — opaque, runner-native identifier (e.g. `src/tests/unit/test_auth.py::test_login` for pytest, `src/auth.test.ts > login > with valid creds` for vitest). Pass it directly back to the runner; do not construct or parse it.

Pass `--failed` to scope the run to the `node_id` values in `failures[]` from the last run (narrowing). Once all previously failing tests pass the full suite runs again (scope reset). The result JSON is re-emitted as the final stdout line for inline consumption.

### Fast analysis commands (`lint`, `lint-dockerfile`, `types`, `security`, `coverage`)

```json
{
  "passed": true,
  "failures": []
}
```

- `passed` — `true` if the command exited 0, `false` otherwise
- `failures` — always empty; present for schema consistency

### `dev check`

```json
{
  "passed": true,
  "stages": [
    { "name": "<stage-name>", "passed": true }
  ]
}
```

- `passed` — `true` if all stages exited 0
- `stages` — one entry per stage in pipeline order (`lint-dockerfile`, `format`, `lint`, `types`, `security`, `unit`, `e2e`); `passed` is `true` if the stage exited 0 or was absent from the Dockerfile

Pass `--failed` to skip stages that passed in the previous run (narrowing). Once all stages pass the full pipeline runs again (scope reset). The result JSON is re-emitted as the final stdout line.
