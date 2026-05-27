#!/usr/bin/env tsx
// Provisions the `tribely_app` runtime role and enforces the TRI-206
// append-only posture on `moderation_action_audit`.
//
// Usage:
//   npm run --workspace=@tribely/api db:roles:bootstrap
//
// Required env vars:
//   ADMIN_DATABASE_URL    — Postgres connection URL with superuser / owner privileges.
//   RUNTIME_DB_PASSWORD   — Password to set (or retain) on the tribely_app role.
//
// Optional env vars:
//   RUNTIME_DB_NAME       — Target database name. Defaults to the path component
//                           of ADMIN_DATABASE_URL when unset.
//
// This script is idempotent — safe to re-run on every deploy.

import 'dotenv/config';

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import pg from 'pg';

const { Client } = pg;

// ---------------------------------------------------------------------------
// Environment validation — fail fast with clear messages.
// ---------------------------------------------------------------------------

const adminUrl = process.env.ADMIN_DATABASE_URL;
if (!adminUrl) {
  console.error(
    'ERROR: ADMIN_DATABASE_URL is required. ' +
      'Set it to a Postgres URL with superuser / schema-owner privileges.',
  );
  process.exit(1);
}

const runtimePassword = process.env.RUNTIME_DB_PASSWORD;
if (!runtimePassword) {
  console.error(
    'ERROR: RUNTIME_DB_PASSWORD is required. ' +
      'Set it to the password for the tribely_app runtime role.',
  );
  process.exit(1);
}

// Derive the DB name from the URL path when RUNTIME_DB_NAME is not explicitly set.
const dbName =
  process.env.RUNTIME_DB_NAME ?? new URL(adminUrl).pathname.slice(1);

if (!dbName) {
  console.error(
    'ERROR: Could not derive database name from ADMIN_DATABASE_URL path ' +
      'and RUNTIME_DB_NAME was not set.',
  );
  process.exit(1);
}

// ---------------------------------------------------------------------------
// SQL template loading and variable substitution.
//
// The .sql file uses JS template placeholders (${runtime_password},
// ${db_name}) rather than psql :\`var\` syntax because the pg client does
// not support psql interpolation.
//
// SECURITY: The password is passed through format('%L', ...) inside the SQL
// DO block, which applies Postgres literal quoting (single-quote escaping).
// We do NOT embed the password outside of that format() call, so there is no
// additional shell/string-injection surface. The db_name is used only in a
// GRANT CONNECT ON DATABASE "..." statement where we apply double-quote
// identifier escaping below.
// ---------------------------------------------------------------------------

function escapeIdentifier(name: string): string {
  // Escape double-quotes by doubling them — standard Postgres identifier quoting.
  return name.replace(/"/g, '""');
}

function escapeLiteral(value: string): string {
  // Escape single-quotes by doubling them — matches Postgres E-string quoting.
  return value.replace(/'/g, "''");
}

const __dirname = dirname(fileURLToPath(import.meta.url));
const sqlTemplate = readFileSync(
  join(__dirname, 'bootstrap-runtime-role.sql'),
  'utf8',
);

const sql = sqlTemplate
  .replace(/\$\{runtime_password\}/g, escapeLiteral(runtimePassword))
  .replace(/\$\{db_name\}/g, escapeIdentifier(dbName));

// ---------------------------------------------------------------------------
// Execution.
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const client = new Client({ connectionString: adminUrl });

  await client.connect();

  try {
    console.log('[1/5] Creating tribely_app role if missing...');
    console.log('[2/5] Granting baseline privileges on all current tables...');
    console.log('[3/5] Setting default privileges for future tables...');
    console.log('[4/5] Applying TRI-206 lockdown on moderation_action_audit...');
    console.log('[5/5] Verifying posture...');

    await client.query(sql);

    console.log('bootstrap-runtime-role: completed successfully.');
  } finally {
    await client.end();
  }
}

main().catch((err: unknown) => {
  console.error('bootstrap-runtime-role failed:', err);
  process.exit(1);
});
