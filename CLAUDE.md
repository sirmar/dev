**Purpose**
A developer lifecycle tool called *dev* used to create a language agnistic unified interface for building, testing all the way to creating releases and deploying.

**Tools**
- Bash
- ShellCheck for linting
- ShellSpec for testing
- shfmt for formating

**Features**
- Can be run anywhere from in a repo and find the root automatically.
- Project specific configuration are put in a .dev file.
- Enforces a unified Docker setup. The repo services and its tools will be run in Docker containers using Docker Compose and multi-stage Dockerfiles.
- Uses itself for developer lifecycle operations.
- Script has a subcommand style interface.
- Remove the need for similar looking Makefiles in every project

**Examples**
- Build project image: dev build
- Lint project: dev lint
- Lint file: dev lint file-to-lint.py
- Run unit tests: dev unit
- Enter running container: dev shell

**Code Style**
- dev.sh must remain language agnostic — it orchestrates lifecycle commands without any knowledge of the language or toolchain being used. Language-specific logic (e.g. which files to lint, how to run tests) belongs in the Dockerfile entrypoint scripts, Compose files, or the project's .dev config file.

**Workflow**
- Never run tests, lint, or format commands (shellspec, shellcheck, shfmt). Hooks will handle this.
