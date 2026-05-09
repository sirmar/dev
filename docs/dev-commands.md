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
| `coverage [file...]` | Run tests with coverage report          |
| `types`            | Run static type checking                  |
| `security`         | Run security scanning                     |
| `lock`             | Regenerate lock file                      |
| `check`            | Run format, lint, types, and coverage     |
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

After every `dev unit` run, a result file is written to `out/unit-result.json` regardless of who triggered the run. Schema:

```json
{
  "passed": true,
  "failures": [
    { "node_id": "<runner-native test identifier>" }
  ]
}
```

- `passed` — `true` if the command exited 0, `false` otherwise
- `failures` — list of failing tests; empty when all tests pass
- `node_id` — opaque, runner-native identifier (e.g. `src/tests/unit/test_auth.py::test_login` for pytest). Pass it directly back to the runner; do not construct or parse it.

When `CLAUDECODE=1`, `dev unit` reads `out/unit-result.json` on startup and automatically scopes the run to the `node_id` values in `failures[]` (narrowing). Once all previously failing tests pass the full suite runs again (scope reset). The result JSON is also re-emitted as the final stdout line for inline consumption.
