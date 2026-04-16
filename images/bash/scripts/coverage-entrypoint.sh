#!/bin/sh
shellspec --kcov src/spec && \
  rate=$(grep -o 'line-rate="[^"]*"' coverage/cobertura.xml | head -1 | grep -o '[0-9.]*') && \
  pct=$(echo "$rate * 100" | bc -l | xargs printf "%.1f") && \
  printf '| Metric | %% |\n|--------|---|\n| Lines | %s%%\n' "$pct" > /workspace/out/coverage.md
