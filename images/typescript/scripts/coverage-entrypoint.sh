#!/bin/sh
pnpm vitest run --coverage --reporter=dot && \
  node /usr/local/bin/coverage-summary.js > /workspace/out/coverage.md
