#!/usr/bin/env node
/**
 * Safely free a TCP port held by a process belonging to THIS repository.
 *
 * Usage:
 *   node scripts/kill-port.mjs <port>      # explicit
 *   node scripts/kill-port.mjs             # read PORT from apps/api/.env
 *
 * Behavior:
 *   - Looks up the LISTENing process on <port> via lsof.
 *   - If found AND its current working directory is inside this repo, kills it.
 *   - If found but cwd is outside this repo, refuses to kill and exits 1
 *     with an informative message — protects against killing unrelated work.
 *   - If port is already free, exits 0 silently.
 *
 * Designed to be chained: `node scripts/kill-port.mjs && npm run api:dev`.
 */

import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const PROJECT_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

/** Reads PORT=<n> from apps/api/.env (falls back to 3000). */
function portFromApiEnv() {
  try {
    const envText = readFileSync(resolve(PROJECT_ROOT, 'apps/api/.env'), 'utf8');
    for (const raw of envText.split('\n')) {
      const line = raw.trim();
      if (!line || line.startsWith('#')) continue;
      const m = /^PORT\s*=\s*(\d+)\s*$/.exec(line);
      if (m) return m[1];
    }
  } catch {
    // file missing — fall through
  }
  return '3000';
}

const PORT = process.argv[2] ?? portFromApiEnv();
if (!/^\d+$/.test(PORT)) {
  console.error('Usage: node scripts/kill-port.mjs [<port>]');
  process.exit(2);
}

let listing = '';
try {
  listing = execSync(`lsof -i :${PORT} -sTCP:LISTEN -P -n`, {
    stdio: ['ignore', 'pipe', 'ignore'],
  }).toString();
} catch {
  // lsof exits non-zero when nothing is listening — port is free, nothing to do.
  process.exit(0);
}

const lines = listing.trim().split('\n').slice(1); // skip header

if (lines.length === 0) process.exit(0);

let killedAny = false;
let refusedAny = false;

for (const line of lines) {
  const parts = line.split(/\s+/);
  const cmd = parts[0];
  const pid = parts[1];

  if (!pid || !/^\d+$/.test(pid)) continue;

  let cwd = '';
  try {
    const cwdOut = execSync(`lsof -p ${pid} -d cwd -F n -a`, {
      stdio: ['ignore', 'pipe', 'ignore'],
    }).toString();
    cwd = cwdOut.split('\n').find((l) => l.startsWith('n'))?.slice(1) ?? '';
  } catch {
    cwd = '';
  }

  if (cwd && cwd.startsWith(PROJECT_ROOT)) {
    console.log(`Killing PID ${pid} (${cmd}) — cwd ${cwd}`);
    try {
      execSync(`kill ${pid}`, { stdio: 'inherit' });
      killedAny = true;
    } catch (err) {
      console.error(`Failed to kill PID ${pid}: ${err instanceof Error ? err.message : err}`);
      refusedAny = true;
    }
  } else {
    console.error(`\n× Port ${PORT} is held by PID ${pid} (${cmd}) at ${cwd || 'unknown cwd'}`);
    console.error(`  This process is NOT from this project. Refusing to kill.`);
    console.error(`  To free the port yourself: kill ${pid}\n`);
    refusedAny = true;
  }
}

if (refusedAny && !killedAny) process.exit(1);
process.exit(0);
