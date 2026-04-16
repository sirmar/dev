#!/bin/sh
uv run pytest -q --cov=src/app --cov-report=term src/tests/ && \
  uv run coverage report --format=markdown > /workspace/out/coverage.md
