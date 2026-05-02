#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'run_in'
  Before 'setup_mock_docker'
  After 'teardown_mock_docker'

  It 'mounts src/ as /workspace/src'
    When run run_dev unit
    The output should include '/workspace/src'
    The status should be success
  End

  It 'mounts out/ as /workspace/out'
    When run run_dev unit
    The output should include '/workspace/out'
    The status should be success
  End

  It 'includes network flag when DEV_NETWORK is set'
    write_dev_config "$MOCK_DIR" dev service "DEV_NETWORK=dev_network"
    When run run_dev unit
    The output should include '--network dev_network'
    The status should be success
  End

  It 'omits network flag when DEV_NETWORK is unset'
    When run run_dev unit
    The output should not include '--network'
    The status should be success
  End

  It 'includes port flag when DEV_PORT is set'
    write_dev_config "$MOCK_DIR" dev service "DEV_PORT=8080"
    When run run_dev unit
    The output should include '-p 8080:8080'
    The status should be success
  End

  It 'omits port flag when DEV_PORT is unset'
    When run run_dev unit
    The output should not include '-p '
    The status should be success
  End

  It 'mounts extra volumes when DEV_MOUNTS is set'
    write_dev_config "$MOCK_DIR" dev service "DEV_MOUNTS=./data:/workspace/data"
    When run run_dev unit
    The output should include '/workspace/data'
    The status should be success
  End

  It 'does not pass -it when stdin is not a TTY'
    When run run_dev unit
    The output should not include ' -it'
    The status should be success
  End
End
