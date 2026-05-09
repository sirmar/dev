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
    tool)    echo 'build lint format unit check coverage types security ci' ;;
    image)   echo 'build lint push' ;;
    *)       echo 'build lint format unit check' ;;
  esac
elif [[ "$1" == "supports" ]]; then
  cmd="$2"
  case "$type" in
    service)  [[ " up down logs build lint format unit lock check ci db-migrate shell db-shell watch rebuild push " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    tool)     [[ " build lint format unit check coverage types security ci " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    image)    [[ " build lint push " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    library)  [[ " lint format unit check " == *" $cmd "* ]] && exit 0 || exit 1 ;;
    *)        [[ " build lint format unit check " == *" $cmd "* ]] && exit 0 || exit 1 ;;
  esac
elif [[ "$1" == "ci" ]]; then
  pkg="${2:-.}"
  build_pkgs=() checks_include=() coverage_pkgs=()
  [[ "$type" != "library" ]] && build_pkgs+=("$pkg")
  if [[ -f Dockerfile ]]; then
    while IFS= read -r stage; do
      case "$stage" in
        coverage) coverage_pkgs+=("$pkg") ;;
        build|prod) : ;;
        *) checks_include+=("{\"package\":\"$pkg\",\"target\":\"$stage\"}") ;;
      esac
    done < <(sed -n 's/^FROM .* AS \([a-zA-Z0-9_]*\)$/\1/p' Dockerfile | grep -v '^base$')
  fi
  build_json="$(printf '%s\n' "${build_pkgs[@]+"${build_pkgs[@]}"}" | jq -Rnc '[inputs]')"
  coverage_json="$(printf '%s\n' "${coverage_pkgs[@]+"${coverage_pkgs[@]}"}" | jq -Rnc '[inputs]')"
  checks_json="$(printf '%s\n' "${checks_include[@]+"${checks_include[@]}"}" | jq -sc '{include: .}')"
  printf 'build=%s\nchecks=%s\ncoverage=%s\n' "$build_json" "$checks_json" "$coverage_json"
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

  It 'returns all services when a workflow file changed'
    mkdir -p "$MOCK_DIR/.github/workflows"
    touch "$MOCK_DIR/.github/workflows/ci.yml"
    git -C "$MOCK_DIR" add .
    git -C "$MOCK_DIR" commit -q -m 'add ci workflow'
    When run bash -c "cd '$MOCK_DIR' && bash '$MDEV_SCRIPT' changed HEAD~1"
    The status should be success
    The output should include 'api'
    The output should include 'worker'
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
    When run bash -c "cd '$MOCK_DIR' && CI=true bash '$MDEV_SCRIPT' changed"
    The status should be success
    The output should include 'api'
    The output should not include 'worker'
  End

  It 'diffs against origin/main on a feature branch (HEAD != origin/main)'
    touch "$MOCK_DIR/worker/newfile"
    git -C "$MOCK_DIR" add .
    git -C "$MOCK_DIR" commit -q -m 'change worker'
    When run bash -c "cd '$MOCK_DIR' && CI=true bash '$MDEV_SCRIPT' changed"
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


_write_mock_dev_node_id() {
  local dir="$1" verb="$2"
  cat >"$dir/dev" <<EOF
#!/usr/bin/env bash
type="\$(grep -m1 '^DEV_REPO_TYPE=' .dev 2>/dev/null | cut -d= -f2 | tr -d '"')"
if [[ "\$1" == "completions" ]]; then
  case "\$type" in
    service) echo 'up down logs build lint format unit lock check ci db-migrate shell db-shell watch rebuild push e2e' ;;
    tool)    echo 'build lint format unit check coverage types security ci' ;;
    image)   echo 'build lint push' ;;
    *)       echo 'build lint format unit check e2e' ;;
  esac
elif [[ "\$1" == "supports" ]]; then
  cmd="\$2"
  case "\$type" in
    service)  [[ " up down logs build lint format unit lock check ci db-migrate shell db-shell watch rebuild push e2e " == *" \$cmd "* ]] && exit 0 || exit 1 ;;
    tool)     [[ " build lint format unit check coverage types security ci " == *" \$cmd "* ]] && exit 0 || exit 1 ;;
    image)    [[ " build lint push " == *" \$cmd "* ]] && exit 0 || exit 1 ;;
    library)  [[ " lint format unit check " == *" \$cmd "* ]] && exit 0 || exit 1 ;;
    *)        [[ " build lint format unit check e2e " == *" \$cmd "* ]] && exit 0 || exit 1 ;;
  esac
elif [[ "\$1" == "$verb" ]]; then
  result_json="\${MOCK_RESULT:-{\"passed\":true,\"failures\":[]}}"
  mkdir -p out
  printf '%s\n' "\$result_json" >out/${verb}-result.json
  echo "dev $verb \$*"
else
  echo "dev \$*"
fi
EOF
  chmod +x "$dir/dev"
}

Describe 'cmd node-id result aggregation'
  After 'teardown'

  Parameters
    unit 'unit testing'
    e2e  'e2e testing'
  End

  setup_node_id_agg() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
    _write_mock_dev_node_id "$MOCK_DIR" "$1"
  }

  It "writes workspace out/$1-result.json after mdev $1"
    setup_node_id_agg "$1"
    When run run_mdev "$1"
    The status should be success
    The output should include "$2"
    The file "$MOCK_DIR/out/$1-result.json" should be exist
  End

  It 'includes a services array in the workspace result'
    setup_node_id_agg "$1"
    run_mdev "$1" >/dev/null 2>&1
    When run bash -c "jq -r '.services | length' '$MOCK_DIR/out/$1-result.json'"
    The output should equal '2'
  End

  It 'includes name, passed, and failures for each service'
    setup_node_id_agg "$1"
    run_mdev "$1" >/dev/null 2>&1
    When run bash -c "jq -r '.services[0] | keys | sort | join(\",\")' '$MOCK_DIR/out/$1-result.json'"
    The output should equal 'failures,name,passed'
  End

  It 'sets top-level passed to true when all services pass'
    setup_node_id_agg "$1"
    run_mdev "$1" >/dev/null 2>&1
    When run bash -c "jq -r '.passed' '$MOCK_DIR/out/$1-result.json'"
    The output should equal 'true'
  End

  It 'sets top-level passed to false when any service fails'
    setup_node_id_agg "$1"
    svc_verb="$1"
    cat >"$MOCK_DIR/dev" <<DEVEOF
#!/usr/bin/env bash
if [[ "\$1" == "completions" ]]; then
  echo 'up down logs build lint format unit lock check ci db-migrate shell db-shell watch rebuild push e2e'
elif [[ "\$1" == "supports" ]]; then
  [[ " up down logs build lint format unit lock check ci db-migrate shell db-shell watch rebuild push e2e " == *" \$2 "* ]] && exit 0 || exit 1
elif [[ "\$1" == "$svc_verb" ]]; then
  mkdir -p out
  printf '{"passed":false,"failures":[{"node_id":"test_foo"}]}\n' >out/${svc_verb}-result.json
  echo "dev $svc_verb"
else
  echo "dev \$*"
fi
DEVEOF
    chmod +x "$MOCK_DIR/dev"
    When run run_mdev "$1"
    The status should be success
    The output should include "$2"
    Assert [ "$(jq -r '.passed' "$MOCK_DIR/out/$1-result.json")" = 'false' ]
  End

  It 'omits services with no result file'
    setup_node_id_agg "$1"
    svc_verb="$1"
    cat >"$MOCK_DIR/dev" <<DEVEOF
#!/usr/bin/env bash
svc="\$(basename "\$(pwd)")"
if [[ "\$1" == "completions" ]]; then
  echo 'up down logs build lint format unit lock check ci db-migrate shell db-shell watch rebuild push e2e'
elif [[ "\$1" == "supports" ]]; then
  [[ " up down logs build lint format unit lock check ci db-migrate shell db-shell watch rebuild push e2e " == *" \$2 "* ]] && exit 0 || exit 1
elif [[ "\$1" == "$svc_verb" ]]; then
  if [[ "\$svc" == "worker" ]]; then
    mkdir -p out
    printf '{"passed":true,"failures":[]}\n' >out/${svc_verb}-result.json
  fi
  echo "dev $svc_verb"
else
  echo "dev \$*"
fi
DEVEOF
    chmod +x "$MOCK_DIR/dev"
    run_mdev "$1" >/dev/null 2>&1
    When run bash -c "jq -r '.services | length' '$MOCK_DIR/out/$1-result.json'"
    The output should equal '1'
  End

  It 're-emits aggregated JSON as stdout when CLAUDECODE=1'
    setup_node_id_agg "$1"
    When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$MDEV_SCRIPT' $1"
    The status should be success
    The output should include '"services"'
    The output should include '"passed"'
  End

  It 'does not re-emit aggregated JSON on human runs'
    setup_node_id_agg "$1"
    When run run_mdev "$1"
    The status should be success
    The output should not include '"services"'
  End
End


Describe 'cmd node-id narrowing (service-level)'
  After 'teardown'

  Parameters
    unit
    e2e
  End

  setup_node_id_narrow() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
    _write_mock_dev_node_id "$MOCK_DIR" "$1"
  }

  _write_previous_node_id_result() {
    mkdir -p "$MOCK_DIR/out"
    printf '%s\n' "$2" >"$MOCK_DIR/out/$1-result.json"
  }

  It 'runs all services when no previous workspace result exists'
    setup_node_id_narrow "$1"
    When run run_mdev "$1"
    The status should be success
    The output should include '[api]'
    The output should include '[worker]'
  End

  It 'runs all services when previous result passed (scope reset)'
    setup_node_id_narrow "$1"
    _write_previous_node_id_result "$1" '{"passed":true,"services":[{"name":"api","passed":true,"failures":[]},{"name":"worker","passed":true,"failures":[]}]}'
    When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$MDEV_SCRIPT' $1"
    The status should be success
    The output should include '[api]'
    The output should include '[worker]'
  End

  It 'skips passing services when previous result failed'
    setup_node_id_narrow "$1"
    _write_previous_node_id_result "$1" '{"passed":false,"services":[{"name":"api","passed":true,"failures":[]},{"name":"worker","passed":false,"failures":[{"node_id":"test_foo"}]}]}'
    When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$MDEV_SCRIPT' $1"
    The status should be success
    The output should not include '[api]'
    The output should include '[worker]'
  End

  It 'carries forward the previous result for skipped services'
    setup_node_id_narrow "$1"
    _write_previous_node_id_result "$1" '{"passed":false,"services":[{"name":"api","passed":true,"failures":[]},{"name":"worker","passed":false,"failures":[{"node_id":"test_foo"}]}]}'
    bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$MDEV_SCRIPT' $1" >/dev/null 2>&1
    When run bash -c "jq -r '.services[] | select(.name==\"api\") | .passed' '$MOCK_DIR/out/$1-result.json'"
    The output should equal 'true'
  End

  It 'runs services not present in the previous result'
    setup_node_id_narrow "$1"
    _write_previous_node_id_result "$1" '{"passed":false,"services":[{"name":"api","passed":true,"failures":[]}]}'
    When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$MDEV_SCRIPT' $1"
    The status should be success
    The output should include '[worker]'
  End

  It 'only applies narrowing when CLAUDECODE=1'
    setup_node_id_narrow "$1"
    _write_previous_node_id_result "$1" '{"passed":false,"services":[{"name":"api","passed":true,"failures":[]},{"name":"worker","passed":false,"failures":[{"node_id":"test_foo"}]}]}'
    When run run_mdev "$1"
    The status should be success
    The output should include '[api]'
    The output should include '[worker]'
  End
End

_write_mock_dev_simple_result() {
  local dir="$1" cmd="$2"
  cat >"$dir/dev" <<DEVEOF
#!/usr/bin/env bash
if [[ "\$1" == "completions" ]]; then
  echo 'build lint format unit check coverage types security'
elif [[ "\$1" == "supports" ]]; then
  [[ " build lint format unit check coverage types security " == *" \$2 "* ]] && exit 0 || exit 1
elif [[ "\$1" == "$cmd" ]]; then
  mkdir -p out
  printf '{"passed":true,"failures":[]}\n' >out/${cmd}-result.json
  echo "dev $cmd"
else
  echo "dev \$*"
fi
DEVEOF
  chmod +x "$dir/dev"
}

Describe 'mdev simple result aggregation'
  After 'teardown'

  Parameters
    lint
    types
    security
    coverage
  End

  setup_simple_agg() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
    _write_mock_dev_simple_result "$MOCK_DIR" "$1"
  }

  It "writes workspace out/$1-result.json after mdev $1"
    setup_simple_agg "$1"
    When run run_mdev "$1"
    The status should be success
    The output should include "dev $1"
    The file "$MOCK_DIR/out/$1-result.json" should be exist
  End

  It "sets top-level passed to true when all services pass for $1"
    setup_simple_agg "$1"
    run_mdev "$1" >/dev/null 2>&1
    When run bash -c "jq -r '.passed' '$MOCK_DIR/out/$1-result.json'"
    The output should equal 'true'
  End
End

Describe 'mdev simple result narrowing (CLAUDECODE=1)'
  After 'teardown'

  Parameters
    lint
    types
    security
    coverage
  End

  setup_simple_narrowing() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
    _write_mock_dev_simple_result "$MOCK_DIR" "$1"
    mkdir -p "$MOCK_DIR/out"
    printf '{"passed":false,"failures":[],"services":[{"name":"api","passed":true},{"name":"worker","passed":false}]}\n' \
      >"$MOCK_DIR/out/$1-result.json"
  }

  It "skips services that passed in previous run for $1"
    setup_simple_narrowing "$1"
    When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$MDEV_SCRIPT' $1"
    The status should be success
    The output should not include '[api]'
    The output should include '[worker]'
  End

  It "runs all services when previous result passed (scope reset) for $1"
    setup_simple_narrowing "$1"
    printf '{"passed":true,"failures":[],"services":[{"name":"api","passed":true},{"name":"worker","passed":true}]}\n' \
      >"$MOCK_DIR/out/$1-result.json"
    When run bash -c "cd '$MOCK_DIR' && CLAUDECODE=1 bash '$MDEV_SCRIPT' $1"
    The status should be success
    The output should include '[api]'
    The output should include '[worker]'
  End
End

Describe 'mdev simple result written even when a service fails'
  After 'teardown'

  Parameters
    lint
    types
    security
    coverage
  End

  setup_simple_agg_failing() {
    setup_mock_mdev
    write_service "$MOCK_DIR" api myapp-api service
    write_service "$MOCK_DIR" worker myapp-worker service
    cat >"$MOCK_DIR/dev" <<DEVEOF
#!/usr/bin/env bash
if [[ "\$1" == "completions" ]]; then
  echo 'build lint format unit check coverage types security'
elif [[ "\$1" == "supports" ]]; then
  [[ " build lint format unit check coverage types security " == *" \$2 "* ]] && exit 0 || exit 1
elif [[ "\$1" == "$1" ]]; then
  mkdir -p out
  printf '{"passed":false,"failures":[]}\n' >out/$1-result.json
  echo "dev $1"
  exit 1
else
  echo "dev \$*"
fi
DEVEOF
    chmod +x "$MOCK_DIR/dev"
  }

  It "writes workspace out/$1-result.json even when a service exits non-zero"
    setup_simple_agg_failing "$1"
    run_mdev "$1" >/dev/null 2>&1 || true
    When run bash -c "jq -r '.passed' '$MOCK_DIR/out/$1-result.json'"
    The output should equal 'false'
  End
End
