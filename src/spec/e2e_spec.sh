#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'e2e when e2e stage is missing from Dockerfile'
  setup_e2e_no_stage() { setup_mock_docker_without_stage e2e; }
  Before 'setup_e2e_no_stage'
  After 'teardown_mock_docker'

  It 'prints info and skips without error'
    When run run_dev e2e
    The output should include "no 'e2e' stage found in Dockerfile"
    The status should be success
  End
End

Describe 'e2e when docker-compose.e2e.yml is missing'
  setup_e2e_no_compose() { setup_mock_docker_with_stage e2e; }
  Before 'setup_e2e_no_compose'
  After 'teardown_mock_docker'

  It 'prints info and skips without error'
    When run run_dev e2e
    The output should include 'no docker-compose.e2e.yml found'
    The status should be success
  End
End

Describe 'e2e'
  Before 'setup_mock_e2e'
  After 'teardown_mock_docker'

  It 'builds the e2e stage'
    When run run_dev e2e
    The output should include 'building stage e2e'
    The status should be success
  End

  It 'runs tests via compose'
    When run run_dev e2e
    The output should include 'running e2e tests'
    The output should include 'compose'
    The output should include 'run'
    The output should include 'e2e'
    The status should be success
  End

  It 'cleans up before running'
    When run run_dev e2e
    The output should include 'docker-compose.e2e.yml'
    The output should include 'down -v'
    The status should be success
  End

  It 'does not touch main service compose'
    When run run_dev e2e
    The output should not include 'docker-compose.yml'
    The status should be success
  End

  It 'uses the e2e network compose file'
    When run run_dev e2e
    The output should include 'docker-compose.e2e-network.yml'
    The status should be success
  End
End

Describe 'e2e on failure'
  setup_e2e_failing() {
    setup_mock_docker_with_stage e2e
    touch "$MOCK_DIR/docker-compose.e2e.yml"
    cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
case "$*" in
  *" run --rm e2e") echo "docker $*"; exit 1 ;;
  *) echo "docker $*" ;;
esac
EOF
    chmod +x "$MOCK_DIR/docker"
  }
  Before 'setup_e2e_failing'
  After 'teardown_mock_docker'

  It 'dumps logs in CI'
    When run env CI=1 bash -c "cd '$MOCK_DIR' && bash '$DEV_ROOT/src/app/dev.sh' e2e"
    The output should include 'logs'
    The status should be failure
  End

  It 'does not dump logs locally'
    When run run_dev e2e
    The output should not include 'logs'
    The status should be failure
  End
End

Describe 'e2e skips on image repos'
  setup_e2e_image_repo() {
    setup_mock_e2e
    write_dev_config "$MOCK_DIR" dev image
  }
  Before 'setup_e2e_image_repo'
  After 'teardown_mock_docker'

  It 'skips gracefully'
    When run run_dev e2e
    The status should be success
    The output should include 'skipping e2e'
  End
End
