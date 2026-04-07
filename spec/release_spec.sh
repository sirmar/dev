#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/app/dev.sh"

Describe "release"
It "fails without a bump type"
When run bash "$DEV_SCRIPT" release
The status should be failure
The stderr should include "major|minor|patch"
End

It "fails with invalid bump type"
When run bash "$DEV_SCRIPT" release banana
The status should be failure
The stderr should include "major|minor|patch"
End

setup_git_repo() {
	GIT_DIR="$(mktemp -d)"
	git init -q "$GIT_DIR"
	git -C "$GIT_DIR" config user.email "test@test.com"
	git -C "$GIT_DIR" config user.name "Test"
	touch "$GIT_DIR/.dev"
	cp "$DEV_SCRIPT" "$GIT_DIR/dev.sh"
	git -C "$GIT_DIR" add .
	git -C "$GIT_DIR" commit -q -m "init"
}

teardown_git_repo() {
	rm -rf "$GIT_DIR"
}

Before "setup_git_repo"
After "teardown_git_repo"

It "bumps patch version from v0.0.0"
When run bash -c "cd '$GIT_DIR' && bash dev.sh release patch"
The output should include "v0.0.0 -> v0.0.1"
The status should be success
End

It "bumps minor version and resets patch"
When run bash -c "cd '$GIT_DIR' && git tag v1.2.3 && bash dev.sh release minor"
The output should include "v1.2.3 -> v1.3.0"
The status should be success
End

It "bumps major version and resets minor and patch"
When run bash -c "cd '$GIT_DIR' && git tag v1.2.3 && bash dev.sh release major"
The output should include "v1.2.3 -> v2.0.0"
The status should be success
End
End
