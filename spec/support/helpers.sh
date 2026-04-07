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
