#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

setup_mock_exec() {
	_setup_mock_project
	printf 'FROM scratch AS scripts\n' >>"$MOCK_DIR/Dockerfile"
	write_dev_config "$MOCK_DIR" dev service 'DEV_SCRIPTS="evaluate:scripts/evaluate.py"'
	_finish_mock_docker_setup
}

setup_mock_exec_tool() {
	_setup_mock_project
	write_dev_config "$MOCK_DIR" dev tool 'DEV_SCRIPTS="evaluate:scripts/evaluate.py"'
	printf 'FROM scratch AS scripts\n' >>"$MOCK_DIR/Dockerfile"
	_finish_mock_docker_setup
}

Describe 'exec'
	Before 'setup_mock_exec'
	After 'teardown_mock_docker'

	It 'builds the scripts stage'
		When run run_dev exec evaluate
		The output should include 'docker build'
		The output should include 'scripts'
		The status should be success
	End

	It 'runs the resolved script path'
		When run run_dev exec evaluate
		The output should include 'scripts/evaluate.py'
		The status should be success
	End

	It 'passes arguments to the script'
		When run run_dev exec evaluate --bot maxi
		The output should include '--bot'
		The output should include 'maxi'
		The status should be success
	End

	It 'fails for unknown script name'
		When run run_dev exec unknown
		The output should include 'building stage scripts'
		The stderr should include "unknown script 'unknown'"
		The status should be failure
	End
End

Describe 'exec without scripts stage'
	Before 'setup_mock_docker'
	After 'teardown_mock_docker'

	It 'skips gracefully'
		When run run_dev exec evaluate
		The output should include 'skipping'
		The status should be success
	End
End

Describe 'exec for tool repo'
	Before 'setup_mock_exec_tool'
	After 'teardown_mock_docker'

	It 'is available'
		When run run_dev exec evaluate
		The output should include 'scripts/evaluate.py'
		The status should be success
	End
End
