#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/app/dev.sh"

Describe 'up'
  setup_env() {
    MOCK_DIR="$(mktemp -d)"
    export PATH="$MOCK_DIR:$PATH"
    PROJ_DIR="$(mktemp -d)"
    cp "$DEV_SCRIPT" "$PROJ_DIR/dev.sh"
    printf 'DEV_NAME=myapp\n' >"$PROJ_DIR/.dev"
    printf 'services:\n  api:\n    image: test\n' >"$PROJ_DIR/docker-compose.yml"
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
if [ "$1" = "network" ] && [ "$2" = "inspect" ]; then exit 0; fi
echo "docker $*"
EOF
    chmod +x "$MOCK_DIR/docker"
  }

  teardown_env() {
    rm -rf "$MOCK_DIR" "$PROJ_DIR"
  }

  Before 'setup_env'
  After 'teardown_env'

  It 'starts services with docker compose using DEV_NAME as project name'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh up"
    The output should include 'starting services'
    The output should include 'compose --project-name myapp'
    The output should include 'up -d'
    The status should be success
  End

  It 'passes extra service names to docker compose'
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh up api worker"
    The output should include 'up -d api worker'
    The status should be success
  End

  It 'ensures network exists before starting'
    printf 'DEV_NAME=myapp\nDEV_NETWORK=shared-net\n' >"$PROJ_DIR/.dev"
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
if [ "$1" = "network" ] && [ "$2" = "inspect" ]; then exit 1; fi
echo "docker $*"
EOF
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh up"
    The output should include 'creating network shared-net'
    The output should include 'compose --project-name myapp'
    The status should be success
  End
End
