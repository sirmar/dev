#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

DEV_ROOT="$SHELLSPEC_PROJECT_ROOT"
DEV_SCRIPT="$DEV_ROOT/app/dev.sh"

# shellcheck disable=SC1091
. "$DEV_ROOT/spec/support/helpers.sh"

Describe "lint"
Before "setup_mock_docker"
After "teardown_mock_docker"

It "lints all files when no target given"
When run bash "$DEV_SCRIPT" lint
The output should include "building stage lint"
The output should include "running lint"
The status should be success
End

It "lints a specific file when target given"
When run bash "$DEV_SCRIPT" lint dev.sh
The output should include "building stage lint"
The output should include "running lint on dev.sh"
The status should be success
End
End

Describe "lint --claude passes"
setup_lint_claude_pass() {
	MOCK_DIR="$(mktemp -d)"
	printf '#!/bin/sh\necho "dev.sh"\n' >"$MOCK_DIR/jq"
	printf '#!/bin/sh\nexit 0\n' >"$MOCK_DIR/docker"
	chmod +x "$MOCK_DIR/jq" "$MOCK_DIR/docker"
	export PATH="$MOCK_DIR:$PATH"
}
teardown_lint_claude_pass() { rm -rf "$MOCK_DIR"; }
Before "setup_lint_claude_pass"
After "teardown_lint_claude_pass"

It "exits 0 and produces no stderr"
When run bash -c "echo '{}' | bash '$DEV_SCRIPT' lint --claude"
The status should be success
The output should include "building stage lint"
The output should include "running lint"
The stderr should equal ""
End
End

Describe "lint --claude fails"
setup_lint_claude_fail() {
	MOCK_DIR="$(mktemp -d)"
	printf '#!/bin/sh\necho "dev.sh"\n' >"$MOCK_DIR/jq"
	cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
case "$1" in
build) exit 0 ;;
*) echo "lint error"; exit 1 ;;
esac
EOF
	chmod +x "$MOCK_DIR/jq" "$MOCK_DIR/docker"
	export PATH="$MOCK_DIR:$PATH"
}
teardown_lint_claude_fail() { rm -rf "$MOCK_DIR"; }
Before "setup_lint_claude_fail"
After "teardown_lint_claude_fail"

It "exits non-zero and writes lint output to stderr"
When run bash -c "echo '{}' | bash '$DEV_SCRIPT' lint --claude"
The status should be failure
The output should include "building stage lint"
The output should include "running lint"
The stderr should include "lint error"
End
End

Describe "lint --claude tails long output"
setup_lint_claude_tail() {
	MOCK_DIR="$(mktemp -d)"
	printf '#!/bin/sh\necho "dev.sh"\n' >"$MOCK_DIR/jq"
	cat >"$MOCK_DIR/docker" <<'EOF'
#!/bin/sh
case "$1" in
build) exit 0 ;;
*) for i in $(seq 1 30); do echo "error $i"; done; exit 1 ;;
esac
EOF
	chmod +x "$MOCK_DIR/jq" "$MOCK_DIR/docker"
	export PATH="$MOCK_DIR:$PATH"
}
teardown_lint_claude_tail() { rm -rf "$MOCK_DIR"; }
Before "setup_lint_claude_tail"
After "teardown_lint_claude_tail"

It "only shows last 20 lines on stderr"
When run bash -c "echo '{}' | bash '$DEV_SCRIPT' lint --claude"
The status should be failure
The output should include "building stage lint"
The output should include "running lint"
The stderr should include "error 30"
The stderr should not include "error 10"
End
End
