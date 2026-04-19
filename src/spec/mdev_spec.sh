#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317,SC1091

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
MDEV_SCRIPT="$DEV_ROOT/src/app/mdev.sh"

. "$DEV_ROOT/src/spec/support/helpers.sh"

run_mdev() {
  (cd "$MOCK_DIR" && NO_COLOR=1 bash "$MDEV_SCRIPT" "$@")
}

write_mdev_config() {
  local dir="$1" name="$2"
  shift 2
  printf 'MDEV_NAME=%s\n' "$name" >"$dir/.mdev"
  for extra in "$@"; do
    printf '%s\n' "$extra" >>"$dir/.mdev"
  done
}

write_service() {
  local workspace="$1" service="$2" name="$3" type="${4:-service}"
  mkdir -p "$workspace/$service"
  write_dev_config "$workspace/$service" "$name" "$type"
}

_write_mock_dev() {
  local dir="$1"
  cat >"$dir/dev" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "completions" ]]; then
  type="$(grep -m1 '^DEV_REPO_TYPE=' .dev 2>/dev/null | cut -d= -f2 | tr -d '"')"
  case "$type" in
    service) echo 'up down logs build lint format unit check ci db-migrate shell db-shell watch rebuild' ;;
    tool)    echo 'build lint format unit check coverage types security' ;;
    image)   echo 'build lint' ;;
    *)       echo 'build lint format unit check' ;;
  esac
else
  echo "dev $*"
fi
EOF
  chmod +x "$dir/dev"
}

_write_mock_docker() {
  local dir="$1"
  cat >"$dir/docker" <<'EOF'
#!/bin/sh
case "$1" in
  network)
    case "$2" in
      inspect) exit 1 ;;
      *)       echo "docker $*" ;;
    esac
    ;;
  *) echo "docker $*" ;;
esac
EOF
  chmod +x "$dir/docker"
}

setup_mock_mdev() {
  MOCK_DIR="$(mktemp -d)"
  write_mdev_config "$MOCK_DIR" myapp
  _write_mock_docker "$MOCK_DIR"
  _write_mock_dev "$MOCK_DIR"
  export PATH="$MOCK_DIR:$PATH"
  export MOCK_DIR
}

teardown_mock_mdev() {
  rm -rf "$MOCK_DIR"
}


Describe 'completions'
  It 'lists all mdev commands'
    When run bash "$SHELLSPEC_PROJECT_ROOT/src/app/mdev.sh" completions
    The status should be success
    The output should include 'up'
    The output should include 'down'
    The output should include 'build'
    The output should include 'lint'
    The output should include 'run'
    The output should include 'init'
    The output should include 'help'
  End

  It 'works without a .mdev file'
    When run bash -c "cd /tmp && bash '$MDEV_SCRIPT' completions"
    The status should be success
    The output should include 'up'
  End
End


Describe 'init'
  setup_init() { INIT_DIR="$(mktemp -d)"; export INIT_DIR; }
  teardown_init() { rm -rf "$INIT_DIR"; }
  Before 'setup_init'
  After 'teardown_init'

  It 'creates a .mdev file'
    When run bash -c "cd '$INIT_DIR' && bash '$MDEV_SCRIPT' init"
    The status should be success
    The output should include 'wrote .mdev'
    The file "$INIT_DIR/.mdev" should be exist
  End

  It 'scaffolds MDEV_NAME into the file'
    bash -c "cd '$INIT_DIR' && bash '$MDEV_SCRIPT' init" >/dev/null 2>&1
    When run cat "$INIT_DIR/.mdev"
    The output should include 'MDEV_NAME'
  End

  It 'fails when .mdev already exists'
    touch "$INIT_DIR/.mdev"
    When run bash -c "cd '$INIT_DIR' && bash '$MDEV_SCRIPT' init"
    The status should be failure
    The stderr should include '.mdev already exists'
  End
End


Describe 'find_mdev_root'
  Before 'setup_mock_mdev'
  After 'teardown_mock_mdev'

  It 'finds .mdev in the current directory'
    When run run_mdev help
    The status should be success
    The output should include 'USAGE'
  End

  It 'finds .mdev from a nested subdirectory'
    mkdir -p "$MOCK_DIR/nested/deep"
    When run bash -c "cd '$MOCK_DIR/nested/deep' && bash '$MDEV_SCRIPT' help"
    The status should be success
    The output should include 'USAGE'
  End

  It 'fails when no .mdev file exists'
    When run bash -c "cd /tmp && bash '$MDEV_SCRIPT' help"
    The status should be failure
    The stderr should include 'no .mdev file found'
  End
End


Describe 'MDEV_NAME validation'
  setup_missing_name() {
    setup_mock_mdev
    printf '\n' >"$MOCK_DIR/.mdev"
  }
  Before 'setup_missing_name'
  After 'teardown_mock_mdev'

  It 'errors when MDEV_NAME is not set'
    When run run_mdev help
    The status should be failure
    The stderr should include 'MDEV_NAME is not set'
  End
End


Describe 'main dispatch'
  Before 'setup_mock_mdev'
  After 'teardown_mock_mdev'

  It 'shows help for the help command'
    When run run_mdev help
    The status should be success
    The output should include 'USAGE'
    The output should include 'up'
    The output should include 'down'
  End

  It 'shows help for --help flag'
    When run run_mdev --help
    The status should be success
    The output should include 'USAGE'
  End

  It 'shows help when no command is given'
    When run run_mdev
    The status should be success
    The output should include 'USAGE'
  End

  It 'errors on an unknown command'
    When run run_mdev notacommand
    The status should be failure
    The stderr should include "unknown command 'notacommand'"
    The output should include 'USAGE'
  End
End


Describe 'discover_services (auto-discovery)'
  setup_discover() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
  }
  Before 'setup_discover'
  After 'teardown_mock_mdev'

  It 'shows discovered services in help output'
    When run run_mdev help
    The status should be success
    The output should include 'api'
    The output should include 'worker'
  End

End

Describe 'discover_services (no services)'
  Before 'setup_mock_mdev'
  After 'teardown_mock_mdev'

  It 'reports no services found on stderr'
    When run run_mdev build
    The stderr should include 'no services found'
  End
End


Describe 'discover_services (MDEV_SERVICES)'
  setup_explicit() {
    setup_mock_mdev
    write_mdev_config "$MOCK_DIR" myapp "MDEV_SERVICES=api,worker"
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
  }
  Before 'setup_explicit'
  After 'teardown_mock_mdev'

  It 'uses the explicit service list from MDEV_SERVICES'
    When run run_mdev help
    The status should be success
    The output should include 'api'
    The output should include 'worker'
  End

  It 'reports missing service on stderr'
    write_mdev_config "$MOCK_DIR" myapp "MDEV_SERVICES=ghost"
    When run run_mdev build
    The stderr should include "service 'ghost' not found"
  End
End


Describe 'filter_services'
  setup_filter() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
  }
  Before 'setup_filter'
  After 'teardown_mock_mdev'

  It 'runs a command on a specific service only'
    When run run_mdev build api
    The status should be success
    The output should include '[api]'
    The output should not include '[worker]'
  End

  It 'reports unknown service on stderr'
    When run run_mdev build ghost
    The stderr should include "unknown service 'ghost'"
  End
End


Describe 'up'
  setup_up() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_up'
  After 'teardown_mock_mdev'

  It 'logs that it is starting each service'
    When run run_mdev up
    The status should be success
    The output should include '[myapp]'
    The output should include 'starting api'
  End

  It 'delegates to dev up and labels output'
    When run run_mdev up
    The status should be success
    The output should include '[api] dev up'
  End
End



Describe 'rebuild'
  setup_rebuild() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_rebuild'
  After 'teardown_mock_mdev'

  It 'delegates to dev rebuild and labels output'
    When run run_mdev rebuild
    The status should be success
    The output should include '[api] dev rebuild'
  End
End


Describe 'ci'
  setup_ci() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_ci'
  After 'teardown_mock_mdev'

  It 'delegates to dev ci and labels output'
    When run run_mdev ci
    The status should be success
    The output should include '[api] dev ci'
  End
End


Describe 'down'
  setup_down() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_down'
  After 'teardown_mock_mdev'

  It 'logs that it is stopping each service'
    When run run_mdev down
    The status should be success
    The output should include '[myapp]'
    The output should include 'stopping api'
  End

  It 'delegates to dev down and labels output'
    When run run_mdev down
    The status should be success
    The output should include '[api] dev down'
  End
End


Describe 'build'
  setup_build() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
  }
  Before 'setup_build'
  After 'teardown_mock_mdev'

  It 'builds all services'
    When run run_mdev build
    The status should be success
    The output should include '[api]'
    The output should include '[worker]'
  End

  It 'labels build output with the service name'
    When run run_mdev build api
    The status should be success
    The output should include '[api] dev build'
  End
End


Describe 'db-migrate'
  setup_db_migrate() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
  }
  Before 'setup_db_migrate'
  After 'teardown_mock_mdev'

  It 'migrates all services'
    When run run_mdev db-migrate
    The status should be success
    The output should include '[api]'
    The output should include '[worker]'
  End

  It 'labels migrate output with the service name'
    When run run_mdev db-migrate api
    The status should be success
    The output should include '[api] dev db-migrate'
  End
End


Describe 'shell'
  setup_shell() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_shell'
  After 'teardown_mock_mdev'

  It 'delegates to dev shell in the specified service'
    When run run_mdev shell api
    The status should be success
    The output should include 'dev shell'
  End

  It 'errors when no service is specified'
    When run run_mdev shell
    The status should be failure
    The stderr should include 'usage:'
  End
End


Describe 'db-shell'
  setup_db_shell() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_db_shell'
  After 'teardown_mock_mdev'

  It 'delegates to dev db-shell in the specified service'
    When run run_mdev db-shell api
    The status should be success
    The output should include 'dev db-shell'
  End

  It 'errors when no service is specified'
    When run run_mdev db-shell
    The status should be failure
    The stderr should include 'usage:'
  End
End


Describe 'skip unsupported commands'
  setup_image() {
    setup_mock_mdev
    write_service "$MOCK_DIR" myimage myimage image
  }
  Before 'setup_image'
  After 'teardown_mock_mdev'

  It 'skips format for image repos'
    When run run_mdev format
    The status should be success
    The output should include 'skipping format'
    The output should include 'image'
  End

  It 'skips unit for image repos'
    When run run_mdev unit
    The status should be success
    The output should include 'skipping unit'
    The output should include 'image'
  End
End


Describe 'run'
  setup_run() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_run'
  After 'teardown_mock_mdev'

  It 'delegates to dev in the specified service'
    When run run_mdev run api shell
    The status should be success
    The output should include '[api] dev shell'
  End

  It 'passes extra arguments through to dev'
    When run run_mdev run api unit --watch
    The status should be success
    The output should include '[api] dev unit --watch'
  End

  It 'errors when no service is specified'
    When run run_mdev run
    The status should be failure
    The stderr should include 'usage:'
  End

  It 'errors when no command is specified'
    When run run_mdev run api
    The status should be failure
    The stderr should include 'usage:'
  End
End


Describe 'changed'
  setup_changed() {
    MOCK_DIR="$(mktemp -d)"
    write_mdev_config "$MOCK_DIR" myapp
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
    git init -q "$MOCK_DIR"
    git -C "$MOCK_DIR" config user.email 'test@test.com'
    git -C "$MOCK_DIR" config user.name 'Test'
    git -C "$MOCK_DIR" add .
    git -C "$MOCK_DIR" commit -q -m 'init'
    touch "$MOCK_DIR/api/newfile"
    git -C "$MOCK_DIR" add .
    git -C "$MOCK_DIR" commit -q -m 'change api'
    _write_mock_docker "$MOCK_DIR"
    _write_mock_dev "$MOCK_DIR"
    export PATH="$MOCK_DIR:$PATH"
    export MOCK_DIR
  }
  teardown_changed() { rm -rf "$MOCK_DIR"; }
  Before 'setup_changed'
  After 'teardown_changed'

  It 'lists services with changed files'
    When run bash -c "cd '$MOCK_DIR' && bash '$MDEV_SCRIPT' changed HEAD~1"
    The status should be success
    The output should include 'api'
    The output should not include 'worker'
  End

  It 'returns nothing when no files changed'
    When run bash -c "cd '$MOCK_DIR' && bash '$MDEV_SCRIPT' changed HEAD"
    The status should be success
    The output should be blank
  End
End


Describe 'status'
  setup_status() {
    setup_mock_mdev
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "compose --project-name") : ;;
  *) echo "docker $*" ;;
esac
EOF
    chmod +x "$MOCK_DIR/docker"
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_status'
  After 'teardown_mock_mdev'

  It 'shows stopped when no containers are running'
    When run run_mdev status
    The status should be success
    The output should include '[api]'
    The output should include 'stopped'
  End
End
