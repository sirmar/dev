#!/bin/sh
if [ $# -gt 0 ]; then
	exec pnpm exec biome format --write "$@"
fi
exec pnpm exec biome format --write .
