#!/usr/bin/env node
import { readFileSync } from 'node:fs';

const summary = JSON.parse(readFileSync('coverage/coverage-summary.json', 'utf8')).total;
const rows = Object.entries(summary)
  .map(([k, v]) => `| ${k.charAt(0).toUpperCase() + k.slice(1)} | ${v.pct}% |`)
  .join('\n');
process.stdout.write(`| Metric | % |\n|--------|---|\n${rows}\n`);
