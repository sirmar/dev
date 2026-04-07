#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/app/dev.sh"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe "unit"
Before "setup_mock_docker"
After "teardown_mock_docker"

It "runs unit tests"
When run bash "$DEV_SCRIPT" unit
The output should include "building stage test"
The output should include "running unit"
The output should include "docker run"
The status should be success
End

It "accepts 'test' as an alias"
When run bash "$DEV_SCRIPT" test
The output should include "building stage test"
The output should include "running unit"
The status should be success
End
End

Describe "unit --claude passes"
setup_unit_claude_pass() {
	MOCK_DIR="$(mktemp -d)"
	printf '#!/bin/sh\nexit 0\n' >"$MOCK_DIR/docker"
	chmod +x "$MOCK_DIR/docker"
	export PATH="$MOCK_DIR:$PATH"
}
teardown_unit_claude_pass() { rm -rf "$MOCK_DIR"; }
Before "setup_unit_claude_pass"
After "teardown_unit_claude_pass"

It "exits 0 and produces no stderr"
When run bash -c "echo '{}' | bash '$DEV_SCRIPT' unit --claude"
The status should be success
The output should include "building stage test"
The output should include "running unit"
The stderr should equal ""
End
End

Describe "unit --claude fails"
setup_unit_claude_fail() {
	MOCK_DIR="$(mktemp -d)"
	cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
case "$1" in
build) exit 0 ;;
*) echo "test failure"; exit 1 ;;
esac
EOF
	chmod +x "$MOCK_DIR/docker"
	export PATH="$MOCK_DIR:$PATH"
}
teardown_unit_claude_fail() { rm -rf "$MOCK_DIR"; }
Before "setup_unit_claude_fail"
After "teardown_unit_claude_fail"

It "exits non-zero and writes test output to stderr"
When run bash -c "echo '{}' | bash '$DEV_SCRIPT' unit --claude"
The status should be failure
The output should include "building stage test"
The output should include "running unit"
The stderr should include "test failure"
End
End

Describe "unit --claude tails long output"
setup_unit_claude_tail() {
	MOCK_DIR="$(mktemp -d)"
	cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
case "$1" in
build) exit 0 ;;
*) for i in $(seq 1 30); do echo "failure $i"; done; exit 1 ;;
esac
EOF
	chmod +x "$MOCK_DIR/docker"
	export PATH="$MOCK_DIR:$PATH"
}
teardown_unit_claude_tail() { rm -rf "$MOCK_DIR"; }
Before "setup_unit_claude_tail"
After "teardown_unit_claude_tail"

It "only shows last 20 lines on stderr"
When run bash -c "echo '{}' | bash '$DEV_SCRIPT' unit --claude"
The status should be failure
The output should include "building stage test"
The output should include "running unit"
The stderr should include "failure 30"
The stderr should not include "failure 10"
End
End
