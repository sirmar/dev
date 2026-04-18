#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'DEV_NAME validation'
  setup_missing_dev_name() {
    setup_mock_docker
    printf 'DEV_REPO_TYPE=service\n' >"$MOCK_DIR/.dev"
  }
  Before 'setup_missing_dev_name'
  After 'teardown_mock_docker'

  It 'errors when DEV_NAME is not set'
    When run run_dev help
    The status should be failure
    The stderr should include 'DEV_NAME is not set'
  End
End

Describe 'DEV_REPO_TYPE validation'
  setup_missing_repo_type() {
    setup_mock_docker
    printf 'DEV_NAME=dev\n' >"$MOCK_DIR/.dev"
  }
  Before 'setup_missing_repo_type'
  After 'teardown_mock_docker'

  It 'errors when DEV_REPO_TYPE is not set'
    When run run_dev help
    The status should be failure
    The stderr should include 'DEV_REPO_TYPE is not set'
  End
End

Describe 'DEV_REPO_TYPE=image'
  setup_image_repo() {
    setup_mock_docker
    write_dev_config "$MOCK_DIR" dev image
  }
  Before 'setup_image_repo'
  After 'teardown_mock_docker'

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
  setup_tool_repo() {
    setup_mock_docker
    write_dev_config "$MOCK_DIR" dev tool
  }
  Before 'setup_tool_repo'
  After 'teardown_mock_docker'

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
  setup_e2e_repo() {
    setup_mock_docker
    write_dev_config "$MOCK_DIR" dev e2e "DEV_NETWORK=dev_network"
  }
  Before 'setup_e2e_repo'
  After 'teardown_mock_docker'

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
  setup_image_repo() {
    setup_mock_docker
    write_dev_config "$MOCK_DIR" dev image
  }
  Before 'setup_image_repo'
  After 'teardown_mock_docker'

  It 'skips unit command on image repos'
    When run run_dev unit
    The status should be success
    The output should include 'skipping unit'
  End

  It 'skips shell command on image repos'
    When run run_dev shell
    The status should be success
    The output should include 'skipping shell'
  End

  It 'skips format command on image repos'
    When run run_dev format
    The status should be success
    The output should include 'skipping format'
  End

  It 'skips check command on image repos'
    When run run_dev check
    The status should be success
    The output should include 'skipping check'
  End

  It 'skips coverage command on image repos'
    When run run_dev coverage
    The status should be success
    The output should include 'skipping coverage'
  End

  It 'skips types command on image repos'
    When run run_dev types
    The status should be success
    The output should include 'skipping types'
  End

  It 'skips security command on image repos'
    When run run_dev security
    The status should be success
    The output should include 'skipping security'
  End

  It 'skips run command on image repos'
    When run run_dev run
    The status should be success
    The output should include 'skipping run'
  End

  It 'skips up command on image repos'
    When run run_dev up
    The status should be success
    The output should include 'skipping up'
  End

  It 'skips down command on image repos'
    When run run_dev down
    The status should be success
    The output should include 'skipping down'
  End

  It 'skips db-shell command on image repos'
    When run run_dev db-shell
    The status should be success
    The output should include 'skipping db-shell'
  End

  It 'skips db-migrate command on image repos'
    When run run_dev db-migrate
    The status should be success
    The output should include 'skipping db-migrate'
  End
End

Describe 'assert_repo_type guard on tool repos'
  setup_tool_repo() {
    setup_mock_docker
    write_dev_config "$MOCK_DIR" dev tool
  }
  Before 'setup_tool_repo'
  After 'teardown_mock_docker'

  It 'skips watch command on tool repos'
    When run run_dev watch
    The status should be success
    The output should include 'skipping watch'
  End

  It 'skips shell command on tool repos'
    When run run_dev shell
    The status should be success
    The output should include 'skipping shell'
  End

  It 'skips up command on tool repos'
    When run run_dev up
    The status should be success
    The output should include 'skipping up'
  End

  It 'skips down command on tool repos'
    When run run_dev down
    The status should be success
    The output should include 'skipping down'
  End

  It 'skips db-shell command on tool repos'
    When run run_dev db-shell
    The status should be success
    The output should include 'skipping db-shell'
  End

  It 'skips db-migrate command on tool repos'
    When run run_dev db-migrate
    The status should be success
    The output should include 'skipping db-migrate'
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
    write_dev_config "$MOCK_DIR" dev service "DEV_CONTEXT=services/api"
  }
  Before 'setup_custom_context'
  After 'teardown_mock_docker'

  It 'uses DEV_CONTEXT as build context while Dockerfile stays at project root'
    When run run_dev build
    The output should match pattern '*docker build*-f */Dockerfile */services/api'
    The status should be success
  End
End
