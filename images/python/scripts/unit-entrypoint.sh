#!/bin/sh
if [ $# -gt 0 ]; then
	exec uv run pytest "$@"
else
	exec uv run pytest -q src/tests/unit/
fi
