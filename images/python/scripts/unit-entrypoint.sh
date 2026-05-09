#!/bin/sh
if [ $# -gt 0 ]; then
	uv run pytest --junit-xml=/workspace/out/unit-junit.xml "$@"
else
	uv run pytest -q --junit-xml=/workspace/out/unit-junit.xml src/tests/unit/
fi
pytest_exit=$?
unit-normalizer /workspace/out/unit-junit.xml /workspace/out/unit-result.json
exit $pytest_exit
