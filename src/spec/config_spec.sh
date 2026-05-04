#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'DEV_NAME validation'
  setup_missing_dev_name() {
    fixture_service_repo
    printf 'DEV_REPO_TYPE=service\n' >"$MOCK_DIR/.dev"
  }
  Before 'setup_missing_dev_name'
  After 'teardown'

  It 'errors when DEV_NAME is not set'
    When run run_dev help
    The status should be failure
    The stderr should include 'DEV_NAME is not set'
  End
End

Describe 'DEV_REPO_TYPE validation'
  setup_missing_repo_type() {
    fixture_service_repo
    printf 'DEV_NAME=dev\n' >"$MOCK_DIR/.dev"
  }
  Before 'setup_missing_repo_type'
  After 'teardown'

  It 'errors when DEV_REPO_TYPE is not set'
    When run run_dev help
    The status should be failure
    The stderr should include 'DEV_REPO_TYPE is not set'
  End
End

Describe 'DEV_REPO_TYPE=image'
  Before 'fixture_image_repo'
  After 'teardown'

  It 'shows image repo type in help'
    When run run_dev help
    The output should include 'image'
    The status should be success
  End

  It 'does not show tooling commands in help'
    When run run_dev help
    The output should not include 'unit'
    The output should not include 'coverage'
    The status should be success
  End
End

Describe 'DEV_REPO_TYPE=tool'
  Before 'fixture_tool_repo'
  After 'teardown'

  It 'shows tool repo type in help'
    When run run_dev help
    The output should include 'tool'
    The status should be success
  End

  It 'shows tooling commands in help'
    When run run_dev help
    The output should include 'unit'
    The output should include 'coverage'
    The status should be success
  End

  It 'does not show service-only commands in help'
    When run run_dev help
    The output should not include 'up'
    The output should not include 'down'
    The output should not include 'shell'
    The status should be success
  End
End

Describe 'DEV_REPO_TYPE=e2e'
  Before 'fixture_e2e_repo'
  After 'teardown'

  It 'shows e2e repo type in help'
    When run run_dev help
    The output should include 'e2e'
    The status should be success
  End

  It 'shows lint/format/types/security commands in help'
    When run run_dev help
    The output should include 'lint'
    The output should include 'format'
    The output should include 'types'
    The output should include 'security'
    The status should be success
  End

  It 'shows run command in help'
    When run run_dev help
    The output should include 'run'
    The status should be success
  End

  It 'does not show unit/coverage commands in help'
    When run run_dev help
    The output should not include 'unit'
    The output should not include 'coverage'
    The status should be success
  End

  It 'does not show service-only commands in help'
    When run run_dev help
    The output should not include 'up'
    The output should not include 'down'
    The output should not include 'shell'
    The status should be success
  End

  It 'skips unit command'
    When run run_dev unit
    The status should be success
    The output should include 'skipping unit'
  End

  It 'skips coverage command'
    When run run_dev coverage
    The status should be success
    The output should include 'skipping coverage'
  End

  It 'skips e2e command'
    When run run_dev e2e
    The status should be success
    The output should include 'skipping e2e'
  End
End

Describe 'assert_repo_type guard'
  Before 'fixture_image_repo'
  After 'teardown'

  Parameters
    unit
    shell
    format
    check
    coverage
    types
    security
    run
    up
    down
    db-shell
    db-migrate
  End

  It "skips $1 command on image repos"
    When run run_dev "$1"
    The status should be success
    The output should include "skipping $1"
  End
End

Describe 'assert_repo_type guard on tool repos'
  Before 'fixture_tool_repo'
  After 'teardown'

  Parameters
    watch
    shell
    up
    down
    db-shell
    db-migrate
  End

  It "skips $1 command on tool repos"
    When run run_dev "$1"
    The status should be success
    The output should include "skipping $1"
  End
End

Describe 'DEV_CONTEXT default'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'defaults to . as the build context'
    When run run_dev build
    The output should match pattern '*docker build*-t dev*-f */Dockerfile */.'
    The status should be success
  End
End

Describe 'DEV_CONTEXT custom'
  setup_custom_context() {
    fixture_service_repo
    write_dev_config "$MOCK_DIR" dev service "DEV_CONTEXT=services/api"
  }
  Before 'setup_custom_context'
  After 'teardown'

  It 'uses DEV_CONTEXT as build context while Dockerfile stays at project root'
    When run run_dev build
    The output should match pattern '*docker build*-f */Dockerfile */services/api'
    The status should be success
  End
End
