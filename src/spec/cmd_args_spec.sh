#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/src/app/dev.sh"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

cmd_args() { bash "$DEV_SCRIPT" cmd_args "$@"; }

Describe 'cmd_args'
  It 'returns --no-cache for build'
    When call cmd_args build
    The output should equal '--no-cache'
    The status should be success
  End

  It 'returns major minor patch for release'
    When call cmd_args release
    The output should equal 'major minor patch'
    The status should be success
  End

  It 'returns tool service image library for init'
    When call cmd_args init
    The output should equal 'tool service image library'
    The status should be success
  End

  It 'returns empty for up (dynamic args only)'
    When call cmd_args up
    The output should equal ''
    The status should be success
  End
End
