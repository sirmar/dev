#!/bin/sh
if [ $# -gt 0 ]; then
	pnpm vitest run --coverage "$@"
else
	pnpm vitest run --coverage --reporter=dot
fi &&
	node /usr/local/bin/coverage-summary.js >/workspace/out/coverage.md
