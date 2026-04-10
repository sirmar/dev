#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

setup_mock_tool() {
	_setup_mock_project
	write_dev_config "$MOCK_DIR" dev tool
	_finish_mock_docker_setup
}

Describe 'run'
	Before 'setup_mock_tool'
	After 'teardown_mock_docker'

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
End

Describe 'run for service repo'
	Before 'setup_mock_docker'
	After 'teardown_mock_docker'

	It 'is not available'
		When run run_dev run
		The stderr should include 'not available'
		The status should be failure
	End
End
