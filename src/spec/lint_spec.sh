#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'lint (image repo)'
  setup_lint_image_repo() {
    fixture_service_repo
    write_dev_config "$MOCK_DIR" dev image
  }
  Before 'setup_lint_image_repo'
  After 'teardown_mock_docker'

  It 'does not run the lint stage'
    When run run_dev lint
    The output should not include 'building stage lint'
    The status should be success
  End
End

Describe 'lint when lint stage is missing from Dockerfile'
  setup_lint_no_stage() { fixture_service_repo_without_stage lint; }
  Before 'setup_lint_no_stage'
  After 'teardown_mock_docker'

  It 'prints info and skips without error'
    When run run_dev lint
    The output should include "no 'lint' stage found in Dockerfile"
    The output should not include 'running lint'
    The status should be success
  End
End

Describe 'lint-dockerfile'
  Before 'fixture_service_repo'
  After 'teardown_mock_docker'

  It 'runs hadolint on the Dockerfile'
    When run run_dev lint-dockerfile
    The output should include 'linting Dockerfile'
    The output should include 'hadolint'
    The status should be success
  End
End

Describe 'lint-dockerfile when Dockerfile is missing'
  setup_lint_dockerfile_no_file() {
    fixture_service_repo
    rm -f "$MOCK_DIR/Dockerfile"
  }
  Before 'setup_lint_dockerfile_no_file'
  After 'teardown_mock_docker'

  It 'prints info and skips without error'
    When run run_dev lint-dockerfile
    The output should include 'no Dockerfile found'
    The status should be success
  End
End

Describe 'lint'
  Before 'fixture_service_repo'
  After 'teardown_mock_docker'

  It 'lints all files when no target given'
    When run run_dev lint
    The output should include 'building stage lint'
    The output should include 'running lint'
    The status should be success
  End

  It 'lints a specific file when target given'
    When run run_dev lint dev.sh
    The output should include 'building stage lint'
    The output should include 'running lint in dev.sh'
    The status should be success
  End
End

