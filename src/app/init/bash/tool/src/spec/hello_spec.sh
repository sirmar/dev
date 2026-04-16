#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

Describe '{{DEV_NAME}}'
  It 'prints hello'
    When run src/app/hello.sh
    The output should include 'Hello from {{DEV_NAME}}'
    The status should be success
  End
End
