#!/bin/sh
_run_cmd() { exec pnpm exec biome format --write "$@"; }
# shellcheck source=/dev/null
. entrypoint-helper.sh
run_entrypoint '.' "$@"
