#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/src/spec/support/helpers.sh"

Describe 'db-shell'
	Describe 'when DEV_DB_NAME is not set'
		Before 'setup_mock_docker'
		After 'teardown_mock_docker'

		It 'errors with helpful message'
			When run run_dev db-shell
			The status should be failure
			The stderr should include 'DEV_DB_NAME is not set'
		End
	End

	Describe 'when DEV_DB_NAME is set'
		setup_db_shell() {
			setup_mock_docker
			write_dev_config "$MOCK_DIR" myapp service "DEV_DB_NAME=mydb" "DEV_DB_USER=myuser" "DEV_DB_PASSWORD=secret"
		}
		Before 'setup_db_shell'
		After 'teardown_mock_docker'

		It 'runs mysql in the database container'
			When run run_dev db-shell
			The output should include 'docker exec -it myapp-db mysql'
			The output should include 'myuser'
			The output should include 'mydb'
			The status should be success
		End
	End
End

Describe 'db-migrate'
	Describe 'when DEV_DB_NAME is not set'
		Before 'setup_mock_docker'
		After 'teardown_mock_docker'

		It 'skips gracefully'
			When run run_dev db-migrate
			The status should be success
			The output should include 'skipping db-migrate'
		End
	End

	Describe 'when DEV_DB_NAME is set'
		setup_db_migrate() {
			setup_mock_docker
			write_dev_config "$MOCK_DIR" myapp service "DEV_DB_NAME=mydb" "DEV_DB_USER=myuser" "DEV_DB_PASSWORD=secret"
			mkdir -p "$MOCK_DIR/migrations"
		}
		Before 'setup_db_migrate'
		After 'teardown_mock_docker'

		It 'runs dbmate with the correct database URL'
			When run run_dev db-migrate
			The output should include 'docker run'
			The output should include 'mysql://myuser:secret@myapp-db/mydb'
			The output should include 'ghcr.io/amacneil/dbmate'
			The status should be success
		End

		It 'uses DEV_NETWORK when set'
			export DEV_NETWORK=mynetwork
			When run run_dev db-migrate
			The output should include 'mynetwork'
			The status should be success
		End

		It 'falls back to project default network when DEV_NETWORK is not set'
			When run run_dev db-migrate
			The output should include 'myapp_default'
			The status should be success
		End
	End
End
