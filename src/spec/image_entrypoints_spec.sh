#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



_setup_entrypoint_env() {
  PROJ_DIR="$(mktemp -d)"
  printf '#!/bin/sh\necho "uv $*"\n' >"$PROJ_DIR/uv"
  printf '#!/bin/sh\necho "shellspec $*"\nmkdir -p coverage && printf '"'"'<coverage line-rate="0.90"></coverage>\n'"'"' >coverage/cobertura.xml\n' >"$PROJ_DIR/shellspec"
  printf '#!/bin/sh\necho "pnpm $*"\n' >"$PROJ_DIR/pnpm"
  printf '#!/bin/sh\necho "90.0"\n' >"$PROJ_DIR/bc"
  printf '#!/bin/sh\necho "node $*"\n' >"$PROJ_DIR/node"
  chmod +x "$PROJ_DIR/uv" "$PROJ_DIR/shellspec" "$PROJ_DIR/pnpm" "$PROJ_DIR/bc" "$PROJ_DIR/node"
  cp "$DEV_ROOT/images/shared/scripts/entrypoint-helper.sh" "$PROJ_DIR/entrypoint-helper.sh"
  export PROJ_DIR
}


run_entrypoint() {
  local script="$1"; shift
  PATH="$PROJ_DIR:$PATH" sh "$DEV_ROOT/$script" "$@"
}

Describe 'entrypoint passes file args through'
  Before '_setup_entrypoint_env'
  After 'teardown'

  Parameters
    images/python/scripts/unit-entrypoint.sh      src/tests/unit/foo_test.py
    images/python/scripts/coverage-entrypoint.sh  src/tests/foo_test.py
    images/python/scripts/e2e-entrypoint.sh       src/tests/e2e/foo_test.py
    images/bash/scripts/unit-entrypoint.sh        src/spec/foo_spec.sh
    images/bash/scripts/coverage-entrypoint.sh    src/spec/foo_spec.sh
    images/typescript/scripts/unit-entrypoint.sh  src/foo.test.ts
    images/typescript/scripts/coverage-entrypoint.sh src/foo.test.ts
  End

  It "passes file args through $1"
    When run run_entrypoint "$1" "$2"
    The output should include "$2"
    The status should be success
  End
End

Describe 'python unit-entrypoint default suite'
  Before '_setup_entrypoint_env'
  After 'teardown'

  It 'runs default suite when no args given'
    When run run_entrypoint images/python/scripts/unit-entrypoint.sh
    The output should include 'src/tests/unit'
    The status should be success
  End
End

Describe 'python coverage-entrypoint default suite'
  Before '_setup_entrypoint_env'
  After 'teardown'

  It 'runs default suite when no args given'
    When run run_entrypoint images/python/scripts/coverage-entrypoint.sh
    The output should include 'src/tests'
    The output should include '--cov'
    The status should be success
  End
End

Describe 'python e2e-entrypoint default suite'
  Before '_setup_entrypoint_env'
  After 'teardown'

  It 'runs default suite when no args given'
    When run run_entrypoint images/python/scripts/e2e-entrypoint.sh
    The output should include 'pytest'
    The output should include 'src/tests/e2e'
    The status should be success
  End
End

Describe 'bash unit-entrypoint default suite'
  Before '_setup_entrypoint_env'
  After 'teardown'

  It 'runs default suite when no args given'
    When run run_entrypoint images/bash/scripts/unit-entrypoint.sh
    The output should include 'src/spec'
    The status should be success
  End
End

Describe 'bash coverage-entrypoint default suite'
  Before '_setup_entrypoint_env'
  After 'teardown'

  It 'runs default suite when no args given'
    When run run_entrypoint images/bash/scripts/coverage-entrypoint.sh
    The output should include '--kcov'
    The output should include 'src/spec'
    The status should be success
  End
End

Describe 'typescript unit-entrypoint default suite'
  Before '_setup_entrypoint_env'
  After 'teardown'

  It 'runs default suite when no args given'
    When run run_entrypoint images/typescript/scripts/unit-entrypoint.sh
    The output should include 'vitest run'
    The status should be success
  End
End

Describe 'typescript coverage-entrypoint default suite'
  Before '_setup_entrypoint_env'
  After 'teardown'

  It 'runs default suite when no args given'
    When run run_entrypoint images/typescript/scripts/coverage-entrypoint.sh
    The output should include 'vitest run'
    The output should include '--coverage'
    The status should be success
  End
End
