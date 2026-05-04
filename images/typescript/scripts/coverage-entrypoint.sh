#!/bin/sh
_run_cmd() { pnpm vitest run --coverage "$@"; }
# shellcheck source=/dev/null
. entrypoint-helper.sh
run_entrypoint '--reporter=dot' "$@" &&
	node /usr/local/bin/coverage-summary.js >/workspace/out/coverage.md
