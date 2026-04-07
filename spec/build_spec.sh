#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/app/dev.sh"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe "build"
Before "setup_mock_docker"
After "teardown_mock_docker"

It "builds the app image"
When run bash "$DEV_SCRIPT" build
The output should include "docker build --target app"
The status should be success
End

It "tags the app image as DEV_NAME without a suffix"
When run bash "$DEV_SCRIPT" build
The output should include "docker build --target app -t dev "
The output should not include "docker build --target app -t dev-app"
The status should be success
End
End
