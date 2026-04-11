#!/bin/sh
if [ $# -gt 0 ]; then
	exec pnpm exec biome check "$@"
fi
exec pnpm exec biome check .
