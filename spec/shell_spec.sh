#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe 'shell'
	Before 'setup_mock_docker'
	After 'teardown_mock_docker'

	It 'builds the service image and runs an interactive shell'
		When run run_dev shell
		The output should include 'docker build'
		The output should include 'docker run'
		The output should include 'running shell'
		The status should be success
	End

	It 'mounts the workspace volume'
		When run run_dev shell
		The output should include '/workspace'
		The status should be success
	End
End

Describe 'shell with custom DEV_SHELL'
	setup_shell_bash() {
		setup_mock_docker
		printf 'DEV_NAME=dev\nDEV_SERVICE=app\nDEV_SHELL=bash\n' >"$MOCK_DIR/.dev"
	}
	Before 'setup_shell_bash'
	After 'teardown_mock_docker'

	It 'uses DEV_SHELL as the shell command'
		When run run_dev shell
		The output should include 'bash'
		The status should be success
	End
End
