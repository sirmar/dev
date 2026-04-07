#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/app/dev.sh"

Describe 'ensure_network'
  setup_env() {
    MOCK_DIR="$(mktemp -d)"
    export PATH="$MOCK_DIR:$PATH"
    NET_DIR="$(mktemp -d)"
    cp "$DEV_SCRIPT" "$NET_DIR/dev.sh"
    touch "$NET_DIR/.dev"
  }

  teardown_env() {
    rm -rf "$MOCK_DIR" "$NET_DIR"
  }

  Before 'setup_env'
  After 'teardown_env'

  It 'skips network creation when DEV_NETWORK is not set'
    printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
    chmod +x "$MOCK_DIR/docker"
    When run bash -c "cd '$NET_DIR' && bash dev.sh help"
    The output should not include 'creating network'
    The status should be success
  End

  It 'creates the network when DEV_NETWORK is set and network does not exist'
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
if [ "$1" = "network" ] && [ "$2" = "inspect" ]; then exit 1; fi
echo "docker $*"
EOF
    chmod +x "$MOCK_DIR/docker"
    printf 'DEV_NETWORK=my-net\n' >"$NET_DIR/.dev"
    printf 'services:\n  app:\n    image: test\n' >"$NET_DIR/docker-compose.yml"
    When run bash -c "cd '$NET_DIR' && bash dev.sh up"
    The output should include 'creating network my-net'
    The output should include 'docker network create my-net'
    The status should be success
  End

  It 'skips network creation when network already exists'
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
if [ "$1" = "network" ] && [ "$2" = "inspect" ]; then exit 0; fi
echo "docker $*"
EOF
    chmod +x "$MOCK_DIR/docker"
    printf 'DEV_NETWORK=my-net\n' >"$NET_DIR/.dev"
    printf 'services:\n  app:\n    image: test\n' >"$NET_DIR/docker-compose.yml"
    When run bash -c "cd '$NET_DIR' && bash dev.sh up"
    The output should not include 'creating network'
    The status should be success
  End
End
