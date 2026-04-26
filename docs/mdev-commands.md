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
| `unit [services...]`       | Run unit tests in each service                           |
| `lock [services...]`       | Regenerate lock file in each service                     |
| `check [services...]`      | Run full quality check in each service                   |
| `ci [services...]`         | Build and run full quality check                         |
| `rebuild [services...]`    | Build images and start services                          |
| `db-migrate [services...]` | Run database migrations in each service                  |
| `shell <service>`          | Open a shell in a running service container              |
| `db-shell <service>`       | Open a shell in a running database container             |
| `changed [ref]`            | List services changed since ref (default: `origin/main`) |
| `run <service> <cmd>`      | Run a dev command in a specific service                  |
| `init`                     | Scaffold a `.mdev` file in the current directory         |

Commands that are not applicable to a service's repo type are skipped automatically.

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
