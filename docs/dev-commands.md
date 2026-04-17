# dev commands

| Command            | Description                               |
|--------------------|-------------------------------------------|
| `build`            | Build Docker image(s)                     |
| `lint [file]`      | Lint source files or Dockerfiles          |
| `format [file]`    | Format source files                       |
| `unit`             | Run unit tests                            |
| `coverage`         | Run tests with coverage report            |
| `types`            | Run static type checking                  |
| `security`         | Run security scanning                     |
| `check`            | Run format, lint, types, and coverage     |
| `e2e`              | Run e2e tests                             |
| `watch`            | Run with hot reload                       |
| `shell`            | Open shell in running container           |
| `run [args]`       | Run the tool (tool repos only)            |
| `exec <script>`    | Run a named script in the scripts stage   |
| `up [service...]`  | Start services via Docker Compose         |
| `down [args]`      | Stop services via Docker Compose          |
| `clean`            | Remove all containers and volumes         |
| `logs [-f] [svc]`  | Show service logs (use -f to follow)      |
| `db-shell`         | Enter shell in running database container |
| `db-migrate`       | Run database migrations                   |
| `login`            | Log in to container registry              |
| `push`             | Push image(s) to registry                 |
| `release <type>`   | Create release tag (major\|minor\|patch)  |
