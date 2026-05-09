#!/bin/sh
if [ $# -gt 0 ]; then
	uv run pytest --junit-xml=/workspace/out/e2e-junit.xml "$@"
else
	uv run pytest -q --junit-xml=/workspace/out/e2e-junit.xml src/tests/e2e/
fi
pytest_exit=$?
unit-normalizer /workspace/out/e2e-junit.xml /workspace/out/e2e-result.json
exit $pytest_exit
