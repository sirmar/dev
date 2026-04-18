#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

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

	It 'exposes DEV_PORT when set'
		write_dev_config "$MOCK_DIR" dev tool "DEV_PORT=3000"
		When run run_dev run
		The output should include '-p 3000:3000'
		The status should be success
	End

	It 'does not expose a port when DEV_PORT is unset'
		When run run_dev run
		The output should not include '-p '
		The status should be success
	End

	It 'always mounts out/ as /workspace/out'
		When run run_dev run
		The output should include '/workspace/out'
		The status should be success
	End

	It 'always creates the out/ directory'
		When run run_dev run
		The output should include 'docker run'
		The path "$MOCK_DIR/out" should be directory
		The status should be success
	End

	It 'mounts extra volumes when DEV_MOUNTS is set'
		write_dev_config "$MOCK_DIR" dev tool "DEV_MOUNTS=./data:/workspace/data"
		When run run_dev run
		The output should include '/workspace/data'
		The status should be success
	End
End

Describe 'run for service repo'
	Before 'setup_mock_docker'
	After 'teardown_mock_docker'

	It 'skips gracefully'
		When run run_dev run
		The output should include 'skipping run'
		The status should be success
	End
End

Describe 'run for e2e repo'
	Before 'setup_mock_e2e_repo'
	After 'teardown_mock_docker'

	It 'runs e2e tests via compose'
		When run run_dev run
		The output should include 'running e2e tests'
		The output should include 'compose'
		The output should include 'run'
		The output should include 'e2e'
		The status should be success
	End

	It 'cleans up before running'
		When run run_dev run
		The output should include 'compose'
		The output should include 'down -v'
		The status should be success
	End

	It 'uses the dev network overlay'
		When run run_dev run
		The output should include 'docker-compose.network.yml'
		The status should be success
	End
End

Describe 'run for e2e repo without docker-compose.yml'
	Before 'setup_mock_e2e_repo_without_compose'
	After 'teardown_mock_docker'

	It 'skips without error'
		When run run_dev run
		The output should include 'no docker-compose.yml found'
		The status should be success
	End
End
