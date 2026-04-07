#!/usr/bin/env bash
# shellcheck shell=bash

setup_mock_docker() {
	MOCK_DIR="$(mktemp -d)"
	printf '#!/bin/sh\necho "docker $*"\n' >"$MOCK_DIR/docker"
	chmod +x "$MOCK_DIR/docker"
	export PATH="$MOCK_DIR:$PATH"
}

teardown_mock_docker() {
	rm -rf "$MOCK_DIR"
}

setup_claude_pass() {
	MOCK_DIR="$(mktemp -d)"
	printf '#!/bin/sh\necho "dev.sh"\n' >"$MOCK_DIR/jq"
	printf '#!/bin/sh\nexit 0\n' >"$MOCK_DIR/docker"
	chmod +x "$MOCK_DIR/jq" "$MOCK_DIR/docker"
	export PATH="$MOCK_DIR:$PATH"
}

teardown_claude_pass() { rm -rf "$MOCK_DIR"; }

setup_claude_fail() {
	local error_msg="$1"
	MOCK_DIR="$(mktemp -d)"
	printf '#!/bin/sh\necho "dev.sh"\n' >"$MOCK_DIR/jq"
	cat >"$MOCK_DIR/docker" <<EOF
#!/bin/sh
case "\$1" in
build) exit 0 ;;
*) echo "$error_msg"; exit 1 ;;
esac
EOF
	chmod +x "$MOCK_DIR/jq" "$MOCK_DIR/docker"
	export PATH="$MOCK_DIR:$PATH"
}

teardown_claude_fail() { rm -rf "$MOCK_DIR"; }

setup_claude_tail() {
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

teardown_claude_tail() { rm -rf "$MOCK_DIR"; }
