#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317



Describe 'run_in'
  Before 'fixture_service_repo'
  After 'teardown'

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

  Describe 'container flag when env var is set'
    Parameters
      'DEV_NETWORK=dev_network' '--network dev_network'
      'DEV_PORT=8080'           '-p 8080:8080'
      'DEV_MOUNTS=./data:/workspace/data' '/workspace/data'
    End

    It "includes $2 when $1 is set"
      write_dev_config "$MOCK_DIR" dev service "$1"
      When run run_dev unit
      The output should include "$2"
      The status should be success
    End
  End

  It 'omits network flag when DEV_NETWORK is unset'
    When run run_dev unit
    The output should not include '--network'
    The status should be success
  End

  It 'omits port flag when DEV_PORT is unset'
    When run run_dev unit
    The output should not include '-p '
    The status should be success
  End

  It 'does not pass -it when stdin is not a TTY'
    When run bash -c "cd '$MOCK_DIR' && bash '$DEV_SCRIPT' unit </dev/null"
    The output should not include ' -it'
    The status should be success
  End
End
