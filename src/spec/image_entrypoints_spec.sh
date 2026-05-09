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
  printf '#!/bin/sh\necho "unit-normalizer $*"\n' >"$PROJ_DIR/unit-normalizer"
  chmod +x "$PROJ_DIR/uv" "$PROJ_DIR/shellspec" "$PROJ_DIR/pnpm" "$PROJ_DIR/bc" "$PROJ_DIR/node" "$PROJ_DIR/unit-normalizer"
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
    images/typescript/scripts/e2e-entrypoint.sh   src/foo.e2e.test.ts
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

Describe 'python e2e-entrypoint result format'
  Before '_setup_entrypoint_env'
  After 'teardown'

  It 'calls unit-normalizer with e2e output after pytest'
    When run run_entrypoint images/python/scripts/e2e-entrypoint.sh
    The output should include 'unit-normalizer'
    The status should be success
  End
End

Describe 'typescript e2e-entrypoint default suite'
  Before '_setup_entrypoint_env'
  After 'teardown'

  It 'runs default suite when no args given'
    When run run_entrypoint images/typescript/scripts/e2e-entrypoint.sh
    The output should include 'vitest run'
    The status should be success
  End

  It 'passes --reporter=json and --outputFile flags'
    When run run_entrypoint images/typescript/scripts/e2e-entrypoint.sh
    The output should include '--reporter=json'
    The output should include '--outputFile'
    The status should be success
  End

  It 'calls unit-normalizer after vitest'
    When run run_entrypoint images/typescript/scripts/e2e-entrypoint.sh
    The output should include 'pnpm vitest run'
    The status should be success
  End
End

Describe 'typescript e2e-entrypoint node_id narrowing'
  Before '_setup_entrypoint_env'
  After 'teardown'

  It 'calls vitest with file and -t test name for a single node_id'
    When run run_entrypoint images/typescript/scripts/e2e-entrypoint.sh 'src/foo.e2e.test.ts > my test'
    The output should include 'src/foo.e2e.test.ts'
    The output should include '-t'
    The output should include 'my test'
    The status should be success
  End

  It 'combines multiple node_ids from same file into one vitest call with combined -t pattern'
    When run run_entrypoint images/typescript/scripts/e2e-entrypoint.sh 'src/foo.e2e.test.ts > test one' 'src/foo.e2e.test.ts > test two'
    The output should include 'src/foo.e2e.test.ts'
    The output should include 'test one|test two'
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

  It 'passes --reporter=json and --outputFile flags'
    When run run_entrypoint images/typescript/scripts/unit-entrypoint.sh
    The output should include '--reporter=json'
    The output should include '--outputFile'
    The status should be success
  End

  It 'calls unit-normalizer after vitest'
    When run run_entrypoint images/typescript/scripts/unit-entrypoint.sh
    The output should include 'pnpm vitest run'
    The status should be success
  End
End

Describe 'typescript unit-entrypoint node_id narrowing'
  Before '_setup_entrypoint_env'
  After 'teardown'

  It 'calls vitest with file and -t test name for a single node_id'
    When run run_entrypoint images/typescript/scripts/unit-entrypoint.sh 'src/foo.test.ts > my test'
    The output should include 'src/foo.test.ts'
    The output should include '-t'
    The output should include 'my test'
    The status should be success
  End

  It 'combines multiple node_ids from same file into one vitest call with combined -t pattern'
    When run run_entrypoint images/typescript/scripts/unit-entrypoint.sh 'src/foo.test.ts > test one' 'src/foo.test.ts > test two'
    The output should include 'src/foo.test.ts'
    The output should include 'test one|test two'
    The status should be success
  End

  It 'runs vitest once per file when node_ids span multiple files'
    When run run_entrypoint images/typescript/scripts/unit-entrypoint.sh 'src/foo.test.ts > test one' 'src/bar.test.ts > test two'
    The output should include 'src/foo.test.ts'
    The output should include 'src/bar.test.ts'
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
