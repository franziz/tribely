---
name: api-create-migration
description: BACKEND ONLY. Create a new Prisma migration script from pending schema.prisma changes. Analyzes the schema diff, suggests a meaningful migration name, warns on destructive changes, and runs `prisma migrate dev` to generate the SQL migration file.
---

# /api-create-migration

```
/api-create-migration                    # detect schema diff, suggest name, prompt to confirm
/api-create-migration <migration-name>   # use the provided name (snake_case, e.g. add_credentials_table)
```

**Scope guard:** Backend API only — Prisma migrations exist for Postgres in `apps/api/`. Refuse if asked about mobile DB migrations (no migration system in mobile right now).

## What this skill does

This skill is for **creating a new migration**, not for applying pending migrations. To apply pending migrations, run `npm run api:db:migrate` directly — `prisma migrate dev` already applies all pending migrations automatically.

The reason this is a skill (and not just an npm script): naming, diff analysis, and destructive-change warnings benefit from AI judgement.

## Workflow

### 1. Detect schema diff

Run:

```bash
cd apps/api && npx prisma migrate diff \
  --from-migrations prisma/migrations \
  --to-schema-datamodel prisma/schema.prisma \
  --script
```

This produces the SQL that would be generated. If the output is empty: tell the user there are no schema changes — nothing to migrate. STOP.

### 2. Analyze the diff

Read the SQL output and `prisma/schema.prisma` to understand:

- **What changed:** added tables, dropped tables, added columns, dropped columns, renamed columns, changed types, added indexes, added constraints.
- **Risk level:** is this destructive (drop column, drop table, change type), additive (new column with default, new table), or neutral (added index)?

### 3. Warn on destructive changes

If the diff includes ANY of:

- `DROP TABLE`
- `DROP COLUMN`
- `ALTER COLUMN ... TYPE` (incompatible type change)
- `RENAME COLUMN` / `RENAME TABLE` (Prisma can't always detect renames — these usually surface as drop+add and lose data)

→ STOP and explain to the user:

- Exactly which columns/tables are affected.
- Whether data will be lost.
- For renames: ask if it's actually a rename (then suggest hand-editing the migration file with `ALTER TABLE ... RENAME` instead of relying on auto-generated drop+add).
- For type changes: ask if a data migration is needed.

Get explicit confirmation before proceeding.

### 4. Suggest a name

Look at the diff and propose a `snake_case` name describing the _intent_, not the _mechanism_:

| Diff                                     | Bad name            | Good name                   |
| ---------------------------------------- | ------------------- | --------------------------- |
| Adds `Event` model                       | `add_event_table`   | `add_events`                |
| Adds `User.locale` column                | `add_locale_column` | `add_user_locale`           |
| Splits `User` into `User` + `Credential` | `migration_2`       | `split_user_and_credential` |
| Adds index on `users.email`              | `add_index`         | `add_users_email_index`     |

Confirm the name with the user. Accept their override.

### 5. Run the migration

```bash
cd apps/api && npx prisma migrate dev --name <confirmed-name>
```

This will:

- Apply any _previous_ unapplied migrations first (if there were any).
- Generate the new migration file at `apps/api/prisma/migrations/<timestamp>_<name>/migration.sql`.
- Apply the new migration.
- Regenerate `@prisma/client` so TypeScript types match the new schema.

If the command fails (e.g. database connection lost, conflicting migration state), surface the error verbatim and stop. Don't try to recover by deleting migrations — that's destructive and needs human judgement.

### 6. Show the generated migration

After success, read `apps/api/prisma/migrations/<latest>/migration.sql` and show the SQL to the user. This catches surprises (Prisma generated something different from what you expected).

## Print after

```
Migration created: apps/api/prisma/migrations/<timestamp>_<name>/migration.sql

Applied to database. @prisma/client regenerated.

NEXT STEPS:
  1. Review the SQL above. If wrong, EDIT it (don't rerun the skill).
     If you edit, then run: npx prisma migrate reset && npm run api:db:migrate
     (only safe in dev — wipes data).
  2. Update mappers (infrastructure/persistence/<aggregate>.mapper.ts) if column
     types or names changed.
  3. Update entity rehydrate() factories if the row shape changed.
  4. Commit the migration file alongside the schema.prisma change.
```

## Refuse

- Asked to create a migration without any schema changes — there's nothing to migrate.
- Asked to "rename a migration" — migrations are immutable history. Suggest creating a follow-up migration instead.
- Asked to apply a migration to production — that's `npm run api:db:migrate:deploy`, which is a different command and should be run by deploy automation, not interactively.
