#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'DEV_CONTEXT default'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'defaults to . as the build context'
    When run run_dev build
    The output should match pattern '*docker build*-t dev*-f */Dockerfile */.'
    The status should be success
  End
End

Describe 'DEV_CONTEXT custom'
  setup_custom_context() {
    setup_mock_docker
    printf 'DEV_NAME=dev\nDEV_SERVICE=app\nDEV_CONTEXT=services/api\n' >"$MOCK_DIR/.dev"
  }
  Before 'setup_custom_context'
  After 'teardown_mock_docker'

  It 'uses DEV_CONTEXT as build context while Dockerfile stays at project root'
    When run run_dev build
    The output should match pattern '*docker build*-f */Dockerfile */services/api'
    The status should be success
  End
End
