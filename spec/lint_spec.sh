#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'lint (image repo)'
  setup_lint_image_repo() {
    setup_mock_docker
    write_dev_config "$MOCK_DIR" dev image
  }
  Before 'setup_lint_image_repo'
  After 'teardown_mock_docker'

  It 'runs hadolint on the Dockerfile'
    When run run_dev lint
    The output should include 'linting Dockerfile'
    The output should include 'docker run'
    The output should include 'hadolint'
    The status should be success
  End

  It 'does not run the lint stage'
    When run run_dev lint
    The output should not include 'building stage lint'
    The status should be success
  End
End

Describe 'lint when lint stage is missing from Dockerfile'
  setup_lint_no_stage() { setup_mock_docker_without_stage lint; }
  teardown_lint_no_stage() { teardown_mock_docker; }
  Before 'setup_lint_no_stage'
  After 'teardown_lint_no_stage'

  It 'prints info and skips without error'
    When run run_dev lint
    The output should include "no 'lint' stage found in Dockerfile"
    The output should not include 'running lint'
    The status should be success
  End
End

Describe 'lint'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'lints all files when no target given'
    When run run_dev lint
    The output should include 'building stage lint'
    The output should include 'running lint'
    The status should be success
  End

  It 'also runs hadolint on the Dockerfile after the lint stage'
    When run run_dev lint
    The output should include 'linting Dockerfile'
    The output should include 'hadolint'
    The status should be success
  End

  It 'lints a specific file when target given'
    When run run_dev lint dev.sh
    The output should include 'building stage lint'
    The output should include 'running lint on dev.sh'
    The status should be success
  End
End

