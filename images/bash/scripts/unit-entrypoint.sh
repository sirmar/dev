#!/bin/sh
_run_cmd() { exec shellspec "$@"; }
# shellcheck source=/dev/null
. entrypoint-helper.sh
run_entrypoint 'src/spec' "$@"
