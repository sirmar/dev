#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

translate_paths_from() {
  local dir="$1"
  shift
  (cd "$dir" && bash "$DEV_ROOT/src/app/dev.sh" translate_paths "$@")
}

Describe 'translate_paths'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'converts a src/-relative path to /workspace/src/...'
    When run translate_paths_from "$MOCK_DIR" src/foo_spec.sh
    The output should equal '/workspace/src/foo_spec.sh'
    The status should be success
  End

  It 'converts multiple paths'
    When run translate_paths_from "$MOCK_DIR" src/a_spec.sh src/b_spec.sh
    The output should equal '/workspace/src/a_spec.sh /workspace/src/b_spec.sh'
    The status should be success
  End

  It 'errors on a path outside src/'
    When run translate_paths_from "$MOCK_DIR" out/foo.txt
    The stderr should include 'error: path must be under src/'
    The status should be failure
  End
End

Describe 'translate_paths with DEV_CONTEXT=..'
  setup_translate_paths_parent_context() {
    setup_mock_docker
    printf 'DEV_CONTEXT=..\n' >>"$MOCK_DIR/.dev"
  }
  Before 'setup_translate_paths_parent_context'
  After 'teardown_mock_docker'

  It 'includes the project directory name in the workspace path'
    project_name="$(basename "$MOCK_DIR")"
    When run translate_paths_from "$MOCK_DIR" src/foo_spec.sh
    The output should equal "/workspace/${project_name}/src/foo_spec.sh"
    The status should be success
  End
End
