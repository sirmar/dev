#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

# Sets up a mock git+docker environment with a tag and registry config.
# docker mock echoes args for build/tag/push; gh mock provides credentials.
setup_push() {
	_setup_mock_project
	write_dev_config "$MOCK_DIR" dev service "DEV_REGISTRY=registry.example.com/org" "DEV_REGISTRY_USER=myuser" "DEV_REGISTRY_TOKEN=mytoken"
	git init -q "$MOCK_DIR"
	git -C "$MOCK_DIR" config user.email 'test@test.com'
	git -C "$MOCK_DIR" config user.name 'Test'
	git -C "$MOCK_DIR" add .
	git -C "$MOCK_DIR" commit -q -m 'init'
	git -C "$MOCK_DIR" tag -a v1.2.3 -m 'Release v1.2.3'
	printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
	chmod +x "$MOCK_DIR/docker"
	# No gh in PATH — falls back to DEV_REGISTRY config
	export PATH="$MOCK_DIR:$PATH"
}

Describe 'push without DEV_REGISTRY'
	Before 'setup_mock_docker'
	After 'teardown_mock_docker'

	It 'errors when DEV_REGISTRY is not set'
		When run run_dev push
		The status should be failure
		The stderr should include 'DEV_REGISTRY is not set'
	End
End

Describe 'push (service repo)'
	Before 'setup_push'
	After 'teardown_mock_docker'

	It 'tags and pushes the app image with the latest git tag'
		When run run_dev push
		The output should include 'pushing registry.example.com/org/dev:v1.2.3'
		The output should include 'docker tag dev registry.example.com/org/dev:v1.2.3'
		The output should include 'docker push registry.example.com/org/dev:v1.2.3'
		The status should be success
	End
End

Describe 'push (image repo)'
	setup_push_image() {
		setup_push
		write_dev_config "$MOCK_DIR" dev image "DEV_REGISTRY=registry.example.com/org" "DEV_REGISTRY_USER=myuser" "DEV_REGISTRY_TOKEN=mytoken"
		printf 'FROM scratch\n' >"$MOCK_DIR/Dockerfile"
	}
	Before 'setup_push_image'
	After 'teardown_mock_docker'

	It 'tags and pushes the image with the latest git tag'
		When run run_dev push
		The output should include 'pushing registry.example.com/org/dev:v1.2.3'
		The output should include 'docker tag dev registry.example.com/org/dev:v1.2.3'
		The output should include 'docker push registry.example.com/org/dev:v1.2.3'
		The status should be success
	End
End

Describe 'push with no git tag'
	setup_push_no_tag() {
		setup_push
		git -C "$MOCK_DIR" tag -d v1.2.3 >/dev/null
	}
	Before 'setup_push_no_tag'
	After 'teardown_mock_docker'

	It 'errors when no git tag exists'
		When run run_dev push
		The status should be failure
		The stderr should include 'no git tag found'
		The output should include 'logging in to'
	End
End
