#!/bin/sh
uv run pytest -q --cov --cov-report=term src/tests/ && \
  uv run coverage report --format=markdown > /workspace/out/coverage.md
