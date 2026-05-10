# mdev commands

`mdev` orchestrates commands across all services in a monorepo. It discovers services by finding `.dev` files in subdirectories of the workspace root (marked by a `.mdev` file).

| Command                    | Description                                              |
|----------------------------|----------------------------------------------------------|
| `up [services...]`         | Start all or specified services                          |
| `down [services...]`       | Stop all or specified services                           |
| `status`                   | Show running/stopped state per service                   |
| `logs [-f] [services...]`  | Show service logs (use -f to follow)                     |
| `build [services...]`      | Build Docker images for services                         |
| `lint [services...]`       | Run lint in each service                                 |
| `format [services...]`     | Run format in each service                               |
| `unit [--failed] [services...]`     | Run unit tests in each service; `--failed` skips services that passed and narrows within failing services |
| `e2e [--failed] [services...]`      | Run e2e tests in each service; `--failed` skips services that passed and narrows within failing services |
| `types [--failed] [services...]`    | Run static type checking in each service; `--failed` skips services that passed |
| `security [--failed] [services...]` | Run security scanning in each service; `--failed` skips services that passed |
| `coverage [--failed] [services...]` | Run tests with coverage in each service; `--failed` skips services that passed |
| `lint [--failed] [services...]`     | Run lint in each service; `--failed` skips services that passed |
| `lock [services...]`                | Regenerate lock file in each service                     |
| `check [--failed] [services...]`    | Run full quality check in each service; `--failed` skips services that passed |
| `ci [services...]`         | Build and run full quality check                         |
| `rebuild [services...]`    | Build images and start services                          |
| `db-migrate [services...]` | Run database migrations in each service                  |
| `shell <service>`          | Open a shell in a running service container              |
| `db-shell <service>`       | Open a shell in a running database container             |
| `changed [ref]`            | List services changed since ref (default: `origin/main`, or `HEAD~1` when on main) |
| `run <service> <cmd>`      | Run a dev command in a specific service                  |
| `init`                     | Scaffold a `.mdev` file in the current directory         |
| `diagnose`                 | Check workspace and service configuration                |

Commands that are not applicable to a service's repo type are skipped automatically.

## Result files

Aggregating commands write a workspace-level result file to `out/` after each run, combining per-service results.

### `mdev unit`, `mdev e2e`

```json
{
  "passed": false,
  "services": [
    {
      "name": "<service>",
      "passed": false,
      "failures": [{ "node_id": "<runner-native test identifier>" }]
    }
  ]
}
```

Pass `--failed` to skip services that passed in the previous run (service-level narrowing) and scope within failing services to their failing tests. Once all services pass the full run executes again (scope reset). The result JSON is re-emitted as the final stdout line.

### `mdev lint`, `mdev types`, `mdev security`, `mdev coverage`

```json
{
  "passed": true,
  "failures": [],
  "services": [
    { "name": "<service>", "passed": true }
  ]
}
```

`passed` is `false` if any service failed. `failures` is always empty. Pass `--failed` to skip services that passed in the previous run (service-level narrowing). Once all services pass the full run executes again (scope reset).

## Workspace config

Place a `.mdev` file at the monorepo root:

```sh
MDEV_NAME=myapp
# MDEV_SERVICES=api,frontend,worker
```

| Key               | Description                                                                 |
|-------------------|-----------------------------------------------------------------------------|
| `MDEV_NAME`       | **Required.** Workspace name, used for logging and shared network naming    |
| `MDEV_SERVICES`   | Optional. Comma-separated list of service paths. Defaults to auto-discovery |
