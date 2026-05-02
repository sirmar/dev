#!/bin/sh
if [ $# -gt 0 ]; then
	exec pnpm vitest run "$@"
else
	exec pnpm vitest run --reporter=dot
fi
