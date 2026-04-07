#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/app/dev.sh"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe "run"
Before "setup_mock_docker"
After "teardown_mock_docker"

It "runs a command in the app container"
When run bash "$DEV_SCRIPT" run echo hello
The output should include "docker run"
The output should include "echo"
The status should be success
End
End
