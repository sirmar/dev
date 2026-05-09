#!/bin/sh
_run_cmd() {
  pnpm vitest run --reporter=dot --reporter=json --outputFile=/workspace/out/unit-raw.json "$@"
  _exit=$?
  unit-normalizer /workspace/out/unit-raw.json /workspace/out/unit-result.json
  exit $_exit
}
# shellcheck source=/dev/null
. entrypoint-helper.sh
run_entrypoint '' "$@"
