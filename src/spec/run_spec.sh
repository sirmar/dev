#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'run'
  Before 'fixture_tool_repo'
  After 'teardown'

  It 'builds the prod image'
    When run run_dev run
    The output should include 'docker build'
    The output should include 'prod'
    The status should be success
  End

  It 'runs the tool container'
    When run run_dev run
    The output should include 'docker run'
    The status should be success
  End

  It 'passes arguments to the tool'
    When run run_dev run --help
    The output should include '--help'
    The status should be success
  End

  It 'passes multiple arguments to the tool'
    When run run_dev run --foo bar
    The output should include '--foo'
    The output should include 'bar'
    The status should be success
  End

  It 'always mounts out/ as /workspace/out'
    When run run_dev run
    The output should include '/workspace/out'
    The status should be success
  End

  It 'always creates the out/ directory'
    When run run_dev run
    The output should include 'docker run'
    The path "$MOCK_DIR/out" should be directory
    The status should be success
  End

  Describe 'container flag when env var is set'
    Parameters
      'DEV_PORT=8080'                      '-p 8080:8080'
      'DEV_MOUNTS=./data:/workspace/data'  '/workspace/data'
      'DEV_NETWORK=dev_network'            '--network dev_network'
    End

    It "includes $2 when $1 is set"
      write_dev_config "$MOCK_DIR" dev tool "$1"
      When run run_dev run
      The output should include "$2"
      The status should be success
    End
  End

  It 'does not expose a port when DEV_PORT is unset'
    When run run_dev run
    The output should not include '-p '
    The status should be success
  End

  It 'omits network flag when DEV_NETWORK is unset'
    When run run_dev run
    The output should not include '--network'
    The status should be success
  End

  It 'does not pass -it when stdin is not a TTY'
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' run </dev/null"
    The output should not include ' -it'
    The status should be success
  End
End

Describe 'run for service repo'
  Before 'fixture_service_repo'
  After 'teardown'

  It 'skips gracefully'
    When run run_dev run
    The output should include 'skipping run'
    The status should be success
  End
End

Describe 'run for e2e repo'
  Before 'fixture_e2e_repo'
  After 'teardown'

  It 'runs e2e tests via compose'
    When run run_dev run
    The output should include 'running e2e tests'
    The output should include 'compose'
    The output should include 'run'
    The output should include 'e2e'
    The status should be success
  End

  It 'cleans up before running'
    When run run_dev run
    The output should include 'compose'
    The output should include 'down -v'
    The status should be success
  End

  It 'uses the dev network overlay'
    When run run_dev run
    The output should include 'docker-compose.network.yml'
    The status should be success
  End
End

Describe 'run for e2e repo without docker-compose.yml'
  setup_e2e_repo_without_compose() {
    fixture_e2e_repo
    rm "$MOCK_DIR/docker-compose.yml"
  }
  Before 'setup_e2e_repo_without_compose'
  After 'teardown'

  It 'skips without error'
    When run run_dev run
    The output should include 'no docker-compose.yml found'
    The status should be success
  End
End
