# Selfie retention sweep — runbook

## Purpose

The selfie retention sweep is a daily in-process scheduled job that purges
selfie images past their 30-day retention window. Operationalizes Tribely's
PDPA s25 commitment (TRI-69 §8): approved selfies and rejected selfies are
deleted from storage 30 days after their approval/rejection timestamp.

Each deletion writes an append-only audit row to `selfie_deletion_events`
(see TRI-82 runbook for that table).

## What the sweep does, on each daily tick

1. Find selfies where `(status='approved' AND approvedAt < now - 30d)` OR
   `(status='rejected' AND rejectedAt < now - 30d)`.
2. For each, in its own DB transaction:
   - Mark the selfie `deleted`, clear `storageKey`.
   - Write an audit row to `selfie_deletion_events` (reason: `retention-sweep`
     for approved-aged, `reviewer-rejection-aged` for rejected-aged).
   - Enqueue a `selfie_pending_storage_deletes` row.
3. After the DB tx commits, attempt the storage delete out-of-band. Failure
   is logged WARN and leaves the row in `selfie_pending_storage_deletes`
   for the next tick's reaper pass.
4. Reaper pass: retry pending storage deletes from prior ticks, up to
   10 attempts each.
5. Write one `sweep_runs` row capturing run timestamps + totals.

## Signals to check

### "Did the sweep run on date X?"

```sql
SELECT * FROM sweep_runs
WHERE kind = 'selfie-retention-sweep'
  AND "startedAt" >= 'YYYY-MM-DD'
  AND "startedAt" < 'YYYY-MM-DD'::date + 1
ORDER BY "startedAt" DESC;
```

If no rows return, the sweep did not run that day. Check API process logs
for boot/shutdown timing.

### Log greppability

The job logs:
- INFO on every successful tick: `Selfie retention sweep complete` with
  `evaluated`, `deleted`, `failed`, `reaperRetried`, `reaperSucceeded`,
  `durationMs` fields.
- WARN on tick-level failure (use case throws): `Selfie retention sweep — tick failed`.

Grep production logs for the INFO/WARN messages above.

### "How many orphaned storage objects are pending retry?"

```sql
SELECT count(*) FROM selfie_pending_storage_deletes;
SELECT * FROM selfie_pending_storage_deletes WHERE attempts >= 10;
```

`attempts >= 10` rows are stuck — the storage delete has failed 10 consecutive
sweeps. Investigate the storage backend; manually delete the object via S3
console once the cause is fixed; then:

```sql
DELETE FROM selfie_pending_storage_deletes WHERE id = '...';
```

## Failure modes

### Spike in `failed` counts on `sweep_runs`

Per-record failures during the eligibility pass. Most likely cause: storage
backend transient unavailability (S3 5xx, network blip). Failed records are
enqueued and retried on the next sweep. If sustained over multiple sweeps,
escalate — check storage backend health.

### Pending storage deletes accumulating

```sql
SELECT count(*) FROM selfie_pending_storage_deletes WHERE attempts >= 1;
```

If this is rising sweep-over-sweep, the reaper is not keeping up with new
failures. Check storage backend; consider increasing sweep frequency
(see env var below).

### Tick-level failure (whole sweep throws)

The job's WARN catch swallows the exception so `setInterval` survives. The
next tick fires after one full interval. If the underlying cause is
persistent (DB connectivity, schema mismatch), the next tick also fails.
Investigate via WARN logs.

## Manual re-run

Use the CLI script when:
- Investigating: want to run the sweep once and inspect the result.
- Recovering: a tick was missed (process restart, deploy window).
- Verifying: just deployed; want to confirm the use case wires up.

```bash
npm run --workspace=@tribely/api sweep:selfies
```

The script prints the `SweepRetainedSelfiesResult` JSON and exits.

## Env var

`SELFIE_RETENTION_SWEEP_INTERVAL_MS` — default `86400000` (24h), floor `60000`
(1 min). Set in `apps/api/.env`. Production should use 24h; dev/test can
lower for verification.

## Scaling path

The sweep is currently single-instance: each API replica that boots will
schedule its own sweep, leading to duplicate work and contention on the
`selfies` and `selfie_pending_storage_deletes` tables under multi-instance
deploys. At launch we run a single instance per environment so this is fine.

When we scale to multiple instances, wrap the tick body in a
`pg_try_advisory_lock(...)` so only one replica's tick executes per interval.
See the code comment near `setInterval` in
`apps/api/src/features/selfies/presentation/jobs/sweep-retained-selfies.job.ts`.

## 24-month audit row purge

Audit rows in `selfie_deletion_events` must be purged at 24 months from
`deletedAt` per PDPA. This is NOT this sweep's job — it's a separate
follow-up ticket (audit-row purge job; deadline T+18 months from first
production deletion). See TRI-69 §8 and the audit-row-purge follow-up ticket.

## Related

- TRI-69 — Selfie retention policy doc (the contract this sweep operationalizes)
- TRI-82 — `selfie_deletion_events` audit table (the audit write target)
- TRI-23 — Selfie capture flow (writes the rows this sweep eventually deletes)
- TRI-5 — File storage port + S3 adapter (the storage backend)
