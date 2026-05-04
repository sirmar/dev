#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

MDEV_SCRIPT="$DEV_ROOT/src/app/mdev.sh"

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
type="$(grep -m1 '^DEV_REPO_TYPE=' .dev 2>/dev/null | cut -d= -f2 | tr -d '"')"
if [[ "$1" == "completions" ]]; then
  case "$type" in
    service) echo 'up down logs build lint format unit lock check ci db-migrate shell db-shell watch rebuild push' ;;
    tool)    echo 'build lint format unit check coverage types security' ;;
    image)   echo 'build lint push' ;;
    *)       echo 'build lint format unit check' ;;
  esac
elif [[ "$1" == "supports" ]]; then
  cmd="$2"
  case "$type" in
    service)  [[ " up down logs build lint format unit lock check ci db-migrate shell db-shell watch rebuild push " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    tool)     [[ " build lint format unit check coverage types security " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    image)    [[ " build lint push " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    library)  [[ " lint format unit check " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    *)        [[ " build lint format unit check " == *" $cmd "* ]] && exit 0 || exit 1 ;;
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


Describe 'cmd_arg_type'
  Parameters
    up          services
    down        services
    build       services
    lint        services
    format      services
    unit        services
    types       services
    security    services
    lock        services
    check       services
    ci          ref
    rebuild     services
    db-migrate  services
    push        services
    run         run
    init        none
  End

  It "returns $2 for $1"
    When run bash "$MDEV_SCRIPT" cmd_arg_type "$1"
    The output should equal "$2"
  End
End

Describe 'completions'
  It 'works without a .mdev file'
    When run bash -c "cd /tmp && bash '$MDEV_SCRIPT' completions"
    The status should be success
    The output should include 'up'
  End
End


Describe 'init'
  Before 'fixture_empty_dir'
  After 'teardown'

  It 'creates a .mdev file'
    When run bash -c "cd '$PROJ_DIR' && bash '$MDEV_SCRIPT' init"
    The status should be success
    The output should include 'wrote .mdev'
    The file "$PROJ_DIR/.mdev" should be exist
  End

  It 'scaffolds MDEV_NAME into the file'
    bash -c "cd '$PROJ_DIR' && bash '$MDEV_SCRIPT' init" >/dev/null 2>&1
    When run cat "$PROJ_DIR/.mdev"
    The output should include 'MDEV_NAME'
  End

  It 'fails when .mdev already exists'
    touch "$PROJ_DIR/.mdev"
    When run bash -c "cd '$PROJ_DIR' && bash '$MDEV_SCRIPT' init"
    The status should be failure
    The stderr should include '.mdev already exists'
  End
End


Describe 'find_mdev_root'
  Before 'setup_mock_mdev'
  After 'teardown'

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
  After 'teardown'

  It 'errors when MDEV_NAME is not set'
    When run run_mdev help
    The status should be failure
    The stderr should include 'MDEV_NAME is not set'
  End
End


Describe 'main dispatch'
  Before 'setup_mock_mdev'
  After 'teardown'

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
  After 'teardown'

  It 'shows discovered services in help output'
    When run run_mdev help
    The status should be success
    The output should include 'api'
    The output should include 'worker'
  End

End

Describe 'discover_services (no services)'
  Before 'setup_mock_mdev'
  After 'teardown'

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
  After 'teardown'

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
  After 'teardown'

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


Describe 'delegation commands'
  setup_delegation() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_delegation'
  After 'teardown'

  Parameters
    up
    down
    rebuild
    lock
  End

  It "delegates $1 to dev and labels output"
    When run run_mdev "$1"
    The status should be success
    The output should include "[api] dev $1"
  End
End


Describe 'up/down lifecycle messages'
  setup_lifecycle() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_lifecycle'
  After 'teardown'

  Parameters
    up   starting
    down stopping
  End

  It "logs '$2 api' when running $1"
    When run run_mdev "$1"
    The status should be success
    The output should include "$2 api"
  End
End


Describe 'multi-service commands'
  setup_multi() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
  }
  Before 'setup_multi'
  After 'teardown'

  Parameters
    build
    db-migrate
    push
  End

  It "runs $1 across all services"
    When run run_mdev "$1"
    The status should be success
    The output should include '[api]'
    The output should include '[worker]'
  End

  It "labels $1 output with the service name"
    When run run_mdev "$1" api
    The status should be success
    The output should include "[api] dev $1"
  End
End


Describe 'interactive commands'
  setup_interactive() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_interactive'
  After 'teardown'

  Parameters
    shell
    db-shell
  End

  It "delegates $1 to dev in the specified service"
    When run run_mdev "$1" api
    The status should be success
    The output should include "dev $1"
  End

  It "errors when no service is specified for $1"
    When run run_mdev "$1"
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
  After 'teardown'

  Parameters
    format
    unit
  End

  It "skips $1 for image repos"
    When run run_mdev "$1"
    The status should be success
    The output should include "skipping $1"
    The output should include 'image'
  End
End


Describe 'run'
  setup_run() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
  }
  Before 'setup_run'
  After 'teardown'

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


_setup_mdev_changed_base() {
  MOCK_DIR="$(mktemp -d)"
  write_mdev_config "$MOCK_DIR" myapp
  write_service "$MOCK_DIR" api myapp-api service
  write_service "$MOCK_DIR" worker myapp-worker service
  git init -q -b main "$MOCK_DIR"
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

Describe 'changed'
  setup_changed() { _setup_mdev_changed_base; }
  Before 'setup_changed'
  After 'teardown'

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


Describe 'changed with remote'
  setup_changed_remote() {
    REMOTE_DIR="$(mktemp -d)"
    git init --bare -q -b main "$REMOTE_DIR"
    _setup_mdev_changed_base
    git -C "$MOCK_DIR" remote add origin "$REMOTE_DIR"
    git -C "$MOCK_DIR" push -q origin main
    export REMOTE_DIR
  }
  teardown_remote() {
    rm -rf "$MOCK_DIR" "$REMOTE_DIR"
  }
  Before 'setup_changed_remote'
  After 'teardown_remote'

  It 'diffs against HEAD~1 when on main (HEAD == origin/main)'
    When run bash -c "cd '$MOCK_DIR' && bash '$MDEV_SCRIPT' changed"
    The status should be success
    The output should include 'api'
    The output should not include 'worker'
  End

  It 'diffs against origin/main on a feature branch (HEAD != origin/main)'
    touch "$MOCK_DIR/worker/newfile"
    git -C "$MOCK_DIR" add .
    git -C "$MOCK_DIR" commit -q -m 'change worker'
    When run bash -c "cd '$MOCK_DIR' && bash '$MDEV_SCRIPT' changed"
    The status should be success
    The output should include 'worker'
    The output should not include 'api'
  End

  It 'uses explicit ref even when HEAD == origin/main'
    When run bash -c "cd '$MOCK_DIR' && bash '$MDEV_SCRIPT' changed HEAD"
    The status should be success
    The output should be blank
  End

  It 'uses explicit ref even on a feature branch'
    touch "$MOCK_DIR/worker/newfile"
    git -C "$MOCK_DIR" add .
    git -C "$MOCK_DIR" commit -q -m 'change worker'
    When run bash -c "cd '$MOCK_DIR' && bash '$MDEV_SCRIPT' changed HEAD~1"
    The status should be success
    The output should include 'worker'
    The output should not include 'api'
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
  After 'teardown'

  It 'shows stopped when no containers are running'
    When run run_mdev status
    The status should be success
    The output should include '[api]'
    The output should include 'stopped'
  End
End


Describe 'diagnose'
  setup_diagnose() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
    cat >"$MOCK_DIR/dev" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "diagnose" ]]; then
  echo "dev diagnose $2"
  exit 0
fi
type="$(grep -m1 '^DEV_REPO_TYPE=' .dev 2>/dev/null | cut -d= -f2 | tr -d '"')"
if [[ "$1" == "completions" ]]; then
  case "$type" in
    service) echo 'up down logs build lint format unit lock check ci db-migrate shell db-shell watch rebuild push' ;;
    tool)    echo 'build lint format unit check coverage types security' ;;
    image)   echo 'build lint push' ;;
    *)       echo 'build lint format unit check' ;;
  esac
elif [[ "$1" == "supports" ]]; then
  cmd="$2"
  case "$type" in
    service)  [[ " up down logs build lint format unit lock check ci db-migrate shell db-shell watch rebuild push " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    tool)     [[ " build lint format unit check coverage types security " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    image)    [[ " build lint push " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    library)  [[ " lint format unit check " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    *)        [[ " build lint format unit check " == *" $cmd "* ]] && exit 0 || exit 1 ;;
  esac
else
  echo "dev $*"
fi
EOF
    chmod +x "$MOCK_DIR/dev"
  }
  Before 'setup_diagnose'
  After 'teardown'

  It 'runs system checks once then repo-only checks per service'
    When run run_mdev diagnose
    The status should be success
    The output should include 'dev diagnose '
    The output should include '[api] dev diagnose --repo-only'
    The output should include '[worker] dev diagnose --repo-only'
  End

  It 'exits 0 when all services pass'
    When run run_mdev diagnose
    The status should be success
    The output should include 'dev diagnose'
  End

  It 'exits 1 when a service dev diagnose fails'
    cat >"$MOCK_DIR/dev" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "diagnose" ]]; then
  echo "dev diagnose failed" >&2
  exit 1
fi
echo "dev $*"
EOF
    chmod +x "$MOCK_DIR/dev"
    When run run_mdev diagnose
    The status should be failure
    The output should include 'diagnosing'
    The error should include 'dev diagnose failed'
  End

  It 'errors when no services are discoverable'
    rm -f "$MOCK_DIR/api/.dev" "$MOCK_DIR/worker/.dev"
    rmdir "$MOCK_DIR/api" "$MOCK_DIR/worker" 2>/dev/null || true
    When run run_mdev diagnose
    The status should be failure
    The stderr should include 'no services found'
  End

  It 'errors for each MDEV_SERVICES entry missing a .dev file'
    write_mdev_config "$MOCK_DIR" myapp "MDEV_SERVICES=api,ghost"
    When run run_mdev diagnose
    The status should be failure
    The stderr should include "ghost"
  End

  It 'is listed in mdev help'
    When run run_mdev help
    The status should be success
    The output should include 'diagnose'
  End
End

_setup_mdev_ci_base() {
  MOCK_DIR="$(mktemp -d)"
  write_mdev_config "$MOCK_DIR" myapp
  write_service "$MOCK_DIR" api myapp-api tool
  cat >"$MOCK_DIR/api/Dockerfile" <<'DOCKERFILE'
FROM base AS base
FROM base AS lint
FROM base AS unit
FROM base AS coverage
DOCKERFILE
  git init -q -b main "$MOCK_DIR"
  git -C "$MOCK_DIR" config user.email 'test@test.com'
  git -C "$MOCK_DIR" config user.name 'Test'
  git -C "$MOCK_DIR" add .
  git -C "$MOCK_DIR" commit -q -m 'init'
  touch "$MOCK_DIR/api/newfile"
  git -C "$MOCK_DIR" add .
  git -C "$MOCK_DIR" commit -q -m 'change api'
  _write_mock_docker "$MOCK_DIR"
  _write_mock_dev "$MOCK_DIR"
  GITHUB_OUTPUT="$(mktemp)"
  export PATH="$MOCK_DIR:$PATH" MOCK_DIR GITHUB_OUTPUT
}

teardown_ci() {
  rm -rf "$MOCK_DIR"
  rm -f "$GITHUB_OUTPUT"
  unset GITHUB_OUTPUT
}

Describe 'ci'
  Before '_setup_mdev_ci_base'
  After 'teardown_ci'

  It 'emits build output for a tool package with a changed file'
    When run bash -c "cd '$MOCK_DIR' && GITHUB_OUTPUT='$GITHUB_OUTPUT' bash '$MDEV_SCRIPT' ci HEAD~1"
    The status should be success
    The file "$GITHUB_OUTPUT" should be exist
    Assert [ "$(grep '^build=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '["api"]' ]
  End

  It 'emits checks output with lint and unit stages (excluding base, build, coverage)'
    When run bash -c "cd '$MOCK_DIR' && GITHUB_OUTPUT='$GITHUB_OUTPUT' bash '$MDEV_SCRIPT' ci HEAD~1"
    The status should be success
    Assert [ "$(grep '^checks=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '{"include":[{"package":"api","target":"lint"},{"package":"api","target":"unit"}]}' ]
  End

  It 'emits coverage output for a package with a coverage stage'
    When run bash -c "cd '$MOCK_DIR' && GITHUB_OUTPUT='$GITHUB_OUTPUT' bash '$MDEV_SCRIPT' ci HEAD~1"
    The status should be success
    Assert [ "$(grep '^coverage=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '["api"]' ]
  End

  It 'emits outputs for multiple changed packages'
    write_service "$MOCK_DIR" worker myapp-worker tool
    cat >"$MOCK_DIR/worker/Dockerfile" <<'DOCKERFILE'
FROM base AS base
FROM base AS lint
DOCKERFILE
    touch "$MOCK_DIR/worker/newfile" "$MOCK_DIR/api/newfile2"
    git -C "$MOCK_DIR" add .
    git -C "$MOCK_DIR" commit -q -m 'change api and worker'
    When run bash -c "cd '$MOCK_DIR' && GITHUB_OUTPUT='$GITHUB_OUTPUT' bash '$MDEV_SCRIPT' ci HEAD~1"
    The status should be success
    Assert [ "$(grep '^build=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '["api","worker"]' ]
  End

  It 'excludes library package from build output'
    write_service "$MOCK_DIR" lib myapp-lib library
    mkdir -p "$MOCK_DIR/lib"
    touch "$MOCK_DIR/lib/newfile2" "$MOCK_DIR/api/newfile2"
    git -C "$MOCK_DIR" add .
    git -C "$MOCK_DIR" commit -q -m 'change api and lib'
    When run bash -c "cd '$MOCK_DIR' && GITHUB_OUTPUT='$GITHUB_OUTPUT' bash '$MDEV_SCRIPT' ci HEAD~1"
    The status should be success
    Assert [ "$(grep '^build=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '["api"]' ]
  End

  It 'emits empty outputs when no packages changed'
    When run bash -c "cd '$MOCK_DIR' && GITHUB_OUTPUT='$GITHUB_OUTPUT' bash '$MDEV_SCRIPT' ci HEAD"
    The status should be success
    Assert [ "$(grep '^build=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '[]' ]
    Assert [ "$(grep '^checks=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '{"include":[]}' ]
    Assert [ "$(grep '^coverage=' "$GITHUB_OUTPUT" | cut -d= -f2-)" = '[]' ]
  End
End
