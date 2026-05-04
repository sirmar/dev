#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



_base_setup_env() {
  MOCK_DIR="$(mktemp -d)"
  export PATH="$MOCK_DIR:$PATH"
  PROJ_DIR="$(mktemp -d)"
  cp "$DEV_SCRIPT" "$PROJ_DIR/dev.sh"
  write_dev_config "$PROJ_DIR" dev service
}

Describe 'ensure_network'
  Before '_base_setup_env'
  After 'teardown'

  It 'skips network creation when DEV_NETWORK is not set'
    printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
    chmod +x "$MOCK_DIR/docker"
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh help"
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
    write_dev_config "$PROJ_DIR" dev service "DEV_NETWORK=my-net"
    printf 'services:\n  app:\n    image: test\n' >"$PROJ_DIR/docker-compose.yml"
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh up"
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
    write_dev_config "$PROJ_DIR" dev service "DEV_NETWORK=my-net"
    printf 'services:\n  app:\n    image: test\n' >"$PROJ_DIR/docker-compose.yml"
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh up"
    The output should not include 'creating network'
    The status should be success
  End
End

Describe 'ensure_e2e_network'
  setup_env() {
    _base_setup_env
    printf 'FROM scratch AS e2e\n' >"$PROJ_DIR/Dockerfile"
    touch "$PROJ_DIR/docker-compose.e2e.yml"
  }

  Before 'setup_env'
  After 'teardown'

  It 'creates the e2e network when it does not exist'
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
if [ "$1" = "network" ] && [ "$2" = "inspect" ]; then exit 1; fi
echo "docker $*"
EOF
    chmod +x "$MOCK_DIR/docker"
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh e2e"
    The output should include 'creating network dev-e2e'
    The output should include 'docker network create dev-e2e'
    The status should be success
  End

  It 'skips network creation when e2e network already exists'
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
if [ "$1" = "network" ] && [ "$2" = "inspect" ]; then exit 0; fi
echo "docker $*"
EOF
    chmod +x "$MOCK_DIR/docker"
    When run bash -c "cd '$PROJ_DIR' && bash dev.sh e2e"
    The output should not include 'creating network'
    The status should be success
  End
End
