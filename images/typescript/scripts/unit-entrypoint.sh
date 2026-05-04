#!/bin/sh
_run_cmd() { exec pnpm vitest run "$@"; }
# shellcheck source=/dev/null
. entrypoint-helper.sh
run_entrypoint '--reporter=dot' "$@"
