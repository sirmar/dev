#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/app/dev.sh"

Describe "find_root"
It "finds .dev file from project root"
When run bash -c "cd '$DEV_ROOT' && bash '$DEV_SCRIPT' help"
The status should be success
The output should include "USAGE"
End

It "finds .dev file from a subdirectory"
When run bash -c "mkdir -p '$DEV_ROOT/tmp/nested' && cd '$DEV_ROOT/tmp/nested' && bash '$DEV_SCRIPT' help; rm -rf '$DEV_ROOT/tmp'"
The status should be success
The output should include "USAGE"
End

It "fails when no .dev file exists"
When run bash -c "cd /tmp && bash '$DEV_SCRIPT' help"
The status should be failure
The stderr should include "no .dev file found"
End
End

Describe "main dispatch"
It "shows help for 'help' command"
When run bash "$DEV_SCRIPT" help
The output should include "USAGE"
The output should include "build"
The output should include "lint"
The output should include "up"
The output should include "down"
The status should be success
End

It "shows help for --help flag"
When run bash "$DEV_SCRIPT" --help
The output should include "USAGE"
The status should be success
End

It "shows help when no command given"
When run bash "$DEV_SCRIPT"
The output should include "USAGE"
The status should be success
End

It "exits with error for unknown command"
When run bash "$DEV_SCRIPT" notacommand
The status should be failure
The stderr should include "unknown command"
The output should include "USAGE"
End
End
