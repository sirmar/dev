#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'DEV_REPO_TYPE default'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'defaults to service'
    When run run_dev help
    The output should include 'service'
    The status should be success
  End
End

Describe 'DEV_REPO_TYPE=image'
  setup_image_repo() {
    setup_mock_docker
    printf 'DEV_NAME=dev\nDEV_SERVICE=app\nDEV_REPO_TYPE=image\n' >"$MOCK_DIR/.dev"
  }
  Before 'setup_image_repo'
  After 'teardown_mock_docker'

  It 'shows image repo type in help'
    When run run_dev help
    The output should include 'image'
    The status should be success
  End

  It 'does not show service-only commands in help'
    When run run_dev help
    The output should not include 'unit'
    The output should not include 'coverage'
    The status should be success
  End
End

Describe 'service_only guard'
  setup_image_repo() {
    setup_mock_docker
    printf 'DEV_NAME=dev\nDEV_SERVICE=app\nDEV_REPO_TYPE=image\n' >"$MOCK_DIR/.dev"
  }
  Before 'setup_image_repo'
  After 'teardown_mock_docker'

  It 'blocks unit command on image repos'
    When run run_dev unit
    The status should be failure
    The stderr should include 'not available for image repos'
  End

  It 'blocks shell command on image repos'
    When run run_dev shell
    The status should be failure
    The stderr should include 'not available for image repos'
  End

  It 'blocks format command on image repos'
    When run run_dev format
    The status should be failure
    The stderr should include 'not available for image repos'
  End

  It 'blocks check command on image repos'
    When run run_dev check
    The status should be failure
    The stderr should include 'not available for image repos'
  End

  It 'blocks coverage command on image repos'
    When run run_dev coverage
    The status should be failure
    The stderr should include 'not available for image repos'
  End

  It 'blocks types command on image repos'
    When run run_dev types
    The status should be failure
    The stderr should include 'not available for image repos'
  End

  It 'blocks security command on image repos'
    When run run_dev security
    The status should be failure
    The stderr should include 'not available for image repos'
  End

  It 'blocks run command on image repos'
    When run run_dev run
    The status should be failure
    The stderr should include 'not available for image repos'
  End

  It 'blocks up command on image repos'
    When run run_dev up
    The status should be failure
    The stderr should include 'not available for image repos'
  End

  It 'blocks down command on image repos'
    When run run_dev down
    The status should be failure
    The stderr should include 'not available for image repos'
  End

  It 'blocks db-shell command on image repos'
    When run run_dev db-shell
    The status should be failure
    The stderr should include 'not available for image repos'
  End

  It 'blocks db-migrate command on image repos'
    When run run_dev db-migrate
    The status should be failure
    The stderr should include 'not available for image repos'
  End
End

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
