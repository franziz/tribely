#!/usr/bin/env tsx
// Operator moderation CLI — stop-gap. Retired by TRI-159 (HTTP admin commands).
//
// Usage:
//   npm run --workspace=@tribely/api moderation list-reports [--state <open|under_review|escalated>]
//   npm run --workspace=@tribely/api moderation touch <reportId> [--operator <userId>]
//   npm run --workspace=@tribely/api moderation resolve <reportId> --hide|--keep --reason <text> \
//     [--override-reason "<text>"] [--operator <userId>]
//   npm run --workspace=@tribely/api moderation cancel-event-for-safety <eventId> \
//     --reason=safety --justification "<text>" [--report-id <reportId>] [--operator <userId>]
//   npm run --workspace=@tribely/api moderation sweep-resolved-reports
//   npm run --workspace=@tribely/api moderation escalate <reportId> \
//     --category <criminal-content|imminent-harm|ambiguous-policy|external-jurisdiction> \
//     --external-ref "<text>" [--note "<text>"] [--operator <userId>]
//   npm run --workspace=@tribely/api moderation record-external-input <reportId> \
//     --source <counsel|partner|imda|other> --disposition "<text>" --received-at <ISO8601> \
//     [--operator <userId>]
//   npm run --workspace=@tribely/api moderation show <reportId>
//
// Operator identity: --operator flag OR $TRIBELY_OPERATOR_USER_ID env var.
// list-reports, sweep-resolved-reports, and show do not require an operator identity.

import { buildContainer } from '@/core/di/container.js';
import { runAsSystem } from '@/core/context/system-context.js';
import { AppError } from '@/core/errors/app-error.js';
import type { Report } from '@/features/reports/domain/entities/report.js';
import type { EscalationCategory } from '@/features/reports/domain/entities/report.js';
import type { ExternalInputSource } from '@/features/audit/domain/types/moderation-action.js';
import {
  SLA_FIRST_TOUCH_HOURS,
  SLA_HARD_CEILING_HOURS,
  APPROACHING_FIRST_TOUCH_HOURS,
  APPROACHING_HARD_CEILING_HOURS,
} from '@/features/reports/application/sla-constants.js';

// ---------------------------------------------------------------------------
// SLA flag computation
// ---------------------------------------------------------------------------

type SlaFlag =
  | 'OK'
  | 'APPROACHING-72H'
  | 'OVERDUE-72H'
  | 'APPROACHING-7D'
  | 'BREACH-7D'
  | 'PAUSED-AT-ESC';

/**
 * Compute the SLA flag for a single unresolved report.
 *
 * Precedence (most severe / most specific wins):
 *   PAUSED-AT-ESC       escalatedAt !== null && resolvedAt === null
 *   BREACH-7D           ageHours >= SLA_HARD_CEILING_HOURS
 *   APPROACHING-7D      ageHours >= APPROACHING_HARD_CEILING_HOURS
 *   OVERDUE-72H         ageHours >= SLA_FIRST_TOUCH_HOURS && firstReviewedAt === null
 *   APPROACHING-72H     ageHours >= APPROACHING_FIRST_TOUCH_HOURS && firstReviewedAt === null
 *   OK                  otherwise
 */
const computeSlaFlag = (report: Report, now: Date): SlaFlag => {
  // Escalated-and-unresolved takes top precedence — SLA is paused.
  if (report.escalatedAt !== null && report.resolvedAt === null) return 'PAUSED-AT-ESC';

  const ageMs = now.getTime() - report.createdAt.getTime();
  const ageHours = ageMs / (1000 * 60 * 60);

  if (ageHours >= SLA_HARD_CEILING_HOURS) return 'BREACH-7D';
  if (ageHours >= APPROACHING_HARD_CEILING_HOURS) return 'APPROACHING-7D';
  if (report.firstReviewedAt === null && ageHours >= SLA_FIRST_TOUCH_HOURS) return 'OVERDUE-72H';
  if (report.firstReviewedAt === null && ageHours >= APPROACHING_FIRST_TOUCH_HOURS)
    return 'APPROACHING-72H';
  return 'OK';
};

// ---------------------------------------------------------------------------
// Table rendering helpers
// ---------------------------------------------------------------------------

const padRight = (s: string, width: number): string => s.padEnd(width, ' ');
const truncate = (s: string, max: number): string =>
  s.length > max ? s.slice(0, max - 1) + '…' : s;

const formatAge = (report: Report, now: Date): string => {
  const ageMs = now.getTime() - report.createdAt.getTime();
  const hours = Math.floor(ageMs / (1000 * 60 * 60));
  if (hours < 24) return `${String(hours)}h`;
  const days = Math.floor(hours / 24);
  return `${String(days)}d`;
};

const formatDate = (d: Date): string => d.toISOString().slice(0, 16).replace('T', ' ');

// ---------------------------------------------------------------------------
// Sub-command implementations
// ---------------------------------------------------------------------------

async function cmdListReports(stateFilter: string | null): Promise<void> {
  if (
    stateFilter !== null &&
    stateFilter !== 'open' &&
    stateFilter !== 'under_review' &&
    stateFilter !== 'escalated'
  ) {
    console.error('Invalid --state: must be one of open, under_review, escalated');
    process.exit(1);
  }

  const container = buildContainer();

  await runAsSystem('cli.moderation.list-reports', async () => {
    const now = new Date();

    // Compute SLA thresholds.
    const approachingFirstTouchBefore = new Date(
      now.getTime() - APPROACHING_FIRST_TOUCH_HOURS * 60 * 60 * 1000,
    );
    const hardCeilingBefore = new Date(now.getTime() - SLA_HARD_CEILING_HOURS * 60 * 60 * 1000);

    // Fetch all unresolved reports (no pagination for CLI — fetch all).
    // listOpenOlderThan is used for SLA bucket membership; listUnresolved
    // for the full moderation queue.
    const [unresolvedResult, approachingFirstTouch, breach7d] = await Promise.all([
      container.reportRepository.listUnresolved({ limit: 100 }),
      // Approaching 72h: open >= 48h (and < 72h) with no firstReviewedAt
      container.reportRepository.listOpenOlderThan({
        createdAtBefore: approachingFirstTouchBefore,
      }),
      // Hard ceiling breach: open >= 7d
      container.reportRepository.listOpenOlderThan({ createdAtBefore: hardCeilingBefore }),
    ]);

    const allReports = unresolvedResult.rows;

    // Apply in-process state filter if requested.
    const filteredReports =
      stateFilter === null
        ? allReports
        : allReports.filter((r) => {
            if (stateFilter === 'open') {
              return r.firstReviewedAt === null && r.escalatedAt === null;
            }
            if (stateFilter === 'under_review') {
              return r.firstReviewedAt !== null && r.escalatedAt === null;
            }
            // stateFilter === 'escalated'
            return r.escalatedAt !== null && r.resolvedAt === null;
          });

    // Compute SLA flags per row.
    const rows = filteredReports.map((r) => ({
      report: r,
      flag: computeSlaFlag(r, now),
    }));

    // Count banners using the SLA bucket queries.
    // Escalated rows are EXCLUDED from banner counts — SLA is paused for them.
    // "approaching 72h" = open for >=48h (older than approachingFirstTouchBefore)
    //   but not yet >=7d, firstReviewedAt null, and NOT escalated.
    const approaching72hReports = approachingFirstTouch.filter(
      (r) =>
        r.firstReviewedAt === null &&
        r.escalatedAt === null &&
        computeSlaFlag(r, now) === 'APPROACHING-72H',
    );
    const breach7dCount = breach7d.filter((r) => r.escalatedAt === null).length;
    const approaching72hCount = approaching72hReports.length;

    // Banner header — only printed when there are reports to flag.
    if (approaching72hCount > 0 || breach7dCount > 0) {
      if (approaching72hCount > 0) {
        console.log(`[!] ${String(approaching72hCount)} reports approaching 72h breach`);
      }
      if (breach7dCount > 0) {
        console.log(`[BREACH] ${String(breach7dCount)} reports past 7d hard ceiling`);
      }
      console.log('');
    }

    if (rows.length === 0) {
      console.log(
        stateFilter !== null
          ? `No unresolved reports matching --state ${stateFilter}.`
          : 'No unresolved reports.',
      );
      return;
    }

    // Print table header.
    // COL_SLA is 14 to accommodate 'PAUSED-AT-ESC' (13 chars) with one pad.
    const COL_ID = 26;
    const COL_REPORTER = 28;
    const COL_TARGET = 28;
    const COL_REASON = 14;
    const COL_CREATED = 17;
    const COL_AGE = 6;
    const COL_SLA = 14;
    const COL_STATE = 14;
    const COL_FIRST_REVIEWED = 17;

    const header = [
      padRight('ID', COL_ID),
      padRight('Reporter', COL_REPORTER),
      padRight('Target', COL_TARGET),
      padRight('Reason', COL_REASON),
      padRight('Created', COL_CREATED),
      padRight('Age', COL_AGE),
      padRight('SLA Flag', COL_SLA),
      padRight('State', COL_STATE),
      padRight('First-Reviewed', COL_FIRST_REVIEWED),
    ].join(' | ');

    const separator = '-'.repeat(header.length);

    console.log(header);
    console.log(separator);

    for (const { report: r, flag } of rows) {
      // Derive human-readable state for the State column.
      const state =
        r.escalatedAt !== null && r.resolvedAt === null
          ? 'escalated'
          : r.firstReviewedAt !== null
            ? 'under_review'
            : 'open';

      const row = [
        padRight(truncate(r.id, COL_ID), COL_ID),
        padRight(truncate(r.reporterUserId, COL_REPORTER), COL_REPORTER),
        padRight(truncate(`${r.target.type}:${r.target.id}`, COL_TARGET), COL_TARGET),
        padRight(truncate(r.reason.value, COL_REASON), COL_REASON),
        padRight(formatDate(r.createdAt), COL_CREATED),
        padRight(formatAge(r, now), COL_AGE),
        padRight(flag, COL_SLA),
        padRight(state, COL_STATE),
        padRight(r.firstReviewedAt ? formatDate(r.firstReviewedAt) : '-', COL_FIRST_REVIEWED),
      ].join(' | ');
      console.log(row);
    }

    console.log(`\nTotal: ${String(rows.length)} unresolved report(s)`);

    // Fetch next page if there are more (informational note only).
    if (unresolvedResult.nextCursor) {
      console.log('[note] More than 100 reports exist — only first 100 shown.');
    }
  });
}

async function cmdTouch(reportId: string, operatorUserId: string): Promise<void> {
  const container = buildContainer();
  console.log(`Acting as ${operatorUserId}`);
  await runAsSystem('cli.moderation.touch', async () => {
    await container.performModerationActionUseCase.execute({
      action: 'touch',
      reportId,
      operatorUserId,
      reason: null,
    });
  });
  console.log(`Touched report ${reportId}`);
}

async function cmdResolve(
  reportId: string,
  isHide: boolean,
  reason: string,
  operatorUserId: string,
  overrideReason: string | null,
): Promise<void> {
  const container = buildContainer();
  const action = isHide ? 'resolve_hidden' : ('resolve_kept' as const);
  const systemLabel = isHide ? 'cli.moderation.resolve-hidden' : 'cli.moderation.resolve-kept';

  console.log(`Acting as ${operatorUserId}`);

  try {
    await runAsSystem(systemLabel, async () => {
      await container.performModerationActionUseCase.execute({
        action,
        reportId,
        operatorUserId,
        reason,
        overrideReason,
      });
    });
  } catch (err) {
    if (err instanceof AppError) {
      const subcode = (err.details as Record<string, unknown> | undefined)?.subcode;
      if (subcode === 'reports.overrideForbiddenForCategory') {
        console.error(
          `${err.message}. Resolve requires a record-external-input row for criminal-content / imminent-harm.`,
        );
        process.exit(1);
      }
      if (subcode === 'reports.escalationResolveBlocked') {
        console.error(
          'Report is escalated. Resolve requires either a record-external-input row OR --override-reason "<text>".',
        );
        process.exit(1);
      }
      if (subcode === 'reports.overrideRequiresEscalation') {
        console.error('--override-reason only valid on escalated reports.');
        process.exit(1);
      }
      if (err.status === 400 || err.status === 404 || err.status === 409 || err.status === 422) {
        console.error(err.message);
        process.exit(1);
      }
    }
    throw err;
  }

  if (isHide) {
    console.log(`Resolved report ${reportId} (hidden)`);
  } else {
    console.log(`Resolved report ${reportId} (kept)`);
  }
}

async function cmdCancelEventForSafety(
  eventId: string,
  justification: string,
  reportId: string | null,
  operatorUserId: string,
): Promise<void> {
  const container = buildContainer();

  console.log(`Acting as ${operatorUserId}`);

  let result: { auditRowId: string; notifiedCount: number };

  try {
    await runAsSystem('cli.moderation.cancel-event-for-safety', async () => {
      result = await container.cancelEventForSafetyUseCase.execute({
        operatorUserId,
        eventId,
        justificationText: justification,
        originatingReportId: reportId,
      });
    });
  } catch (err) {
    if (
      err instanceof AppError &&
      (err.status === 409 || err.status === 404 || err.status === 422)
    ) {
      console.error(err.message);
      process.exit(1);
    }
    throw err;
  }

  // result is guaranteed assigned if runAsSystem did not throw.
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  const { auditRowId, notifiedCount } = result!;
  console.log(`Event ${eventId} cancelled for safety.`);
  console.log(`Audit row: ${auditRowId}`);
  console.log(`Notified attendees: ${String(notifiedCount)}`);
}

async function cmdSweepResolvedReports(): Promise<void> {
  const container = buildContainer();

  let result: {
    evaluated: number;
    deleted: number;
    failed: number;
    auditRowsSevered: number;
    orphanRowsSevered: number;
    durationMs: number;
  };

  await runAsSystem('cli.moderation.sweep-resolved-reports', async () => {
    result = await container.sweepResolvedReportsUseCase.execute();
  });

  // result is guaranteed assigned if runAsSystem did not throw.
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  const { evaluated, deleted, failed, auditRowsSevered, orphanRowsSevered, durationMs } = result!;
  console.log(`Moderation report retention sweep complete.`);
  console.log(`Evaluated: ${String(evaluated)}`);
  console.log(`Deleted: ${String(deleted)}`);
  console.log(`Failed: ${String(failed)}`);
  console.log(`Audit rows severed: ${String(auditRowsSevered)}`);
  console.log(`Orphan rows severed: ${String(orphanRowsSevered)}`);
  console.log(`Duration: ${String(durationMs)}ms`);
}

async function cmdEscalate(
  reportId: string,
  category: string,
  externalRef: string,
  note: string | null,
  operatorUserId: string,
): Promise<void> {
  const container = buildContainer();

  console.log(`Acting as ${operatorUserId}`);

  try {
    await runAsSystem('cli.moderation.escalate', async () => {
      await container.escalateReportUseCase.execute({
        operatorUserId,
        reportId,
        category: category as EscalationCategory,
        externalRef,
        note,
      });
    });
  } catch (err) {
    if (
      err instanceof AppError &&
      (err.status === 400 || err.status === 404 || err.status === 409 || err.status === 422)
    ) {
      console.error(err.message);
      process.exit(1);
    }
    throw err;
  }

  console.log(`Report ${reportId} escalated.`);
  console.log(`Category: ${category}`);
  console.log(`External ref: ${externalRef}`);
  console.log('Audit row written. SLA paused at escalation.');
}

async function cmdRecordExternalInput(
  reportId: string,
  source: string,
  disposition: string,
  receivedAt: Date,
  operatorUserId: string,
): Promise<void> {
  const container = buildContainer();

  console.log(`Acting as ${operatorUserId}`);

  try {
    await runAsSystem('cli.moderation.record-external-input', async () => {
      await container.recordExternalInputUseCase.execute({
        operatorUserId,
        reportId,
        source: source as ExternalInputSource,
        disposition,
        receivedAt,
      });
    });
  } catch (err) {
    if (
      err instanceof AppError &&
      (err.status === 400 || err.status === 404 || err.status === 409 || err.status === 422)
    ) {
      console.error(err.message);
      process.exit(1);
    }
    throw err;
  }

  console.log(`External-input recorded for report ${reportId}.`);
  console.log(`Source: ${source}`);
  console.log(`Received-at: ${receivedAt.toISOString()}`);
  console.log('Audit row written.');
}

async function cmdShow(reportId: string): Promise<void> {
  const container = buildContainer();

  await runAsSystem('cli.moderation.show', async () => {
    const now = new Date();
    const report = await container.reportRepository.findById(reportId);

    if (!report) {
      console.error(`Report ${reportId} not found.`);
      process.exit(1);
    }

    const sla = computeSlaFlag(report, now);
    const elapsed = formatAge(report, now);

    const label = (l: string): string => l.padEnd(18, ' ');
    const iso16 = (d: Date): string => d.toISOString().slice(0, 16);
    const orDash = (v: string | null | undefined): string => v ?? '-';

    console.log(`${label('Report:')}${report.id}`);
    console.log(`${label('Reporter:')}${report.reporterUserId}`);
    console.log(`${label('Target:')}${report.target.type}:${report.target.id}`);
    console.log(`${label('Reason:')}${report.reason.value}`);
    console.log(`${label('Submitted:')}${iso16(report.createdAt)}   (elapsed: ${elapsed})`);
    console.log(
      `${label('First-reviewed:')}${report.firstReviewedAt ? iso16(report.firstReviewedAt) : '-'}`,
    );
    console.log(`${label('Escalated:')}${report.escalatedAt ? iso16(report.escalatedAt) : '-'}`);
    console.log(`${label('Category:')}${orDash(report.escalationCategory)}`);
    console.log(`${label('External ref:')}${orDash(report.externalRef)}`);
    console.log(`${label('External inputs:')}${String(report.externalInputCount)} row(s)`);
    console.log(`${label('Resolved:')}${report.resolvedAt ? iso16(report.resolvedAt) : '-'}`);
    console.log(`${label('Resolution:')}${orDash(report.resolution)}`);
    console.log(`${label('SLA:')}${sla}`);
  });
}

// ---------------------------------------------------------------------------
// CLI helpers
// ---------------------------------------------------------------------------

function parseOperator(args: string[]): string | null {
  const fromFlag = extractFlagValue(args, '--operator');
  return fromFlag ?? process.env.TRIBELY_OPERATOR_USER_ID ?? null;
}

function extractFlagValue(args: string[], flag: string): string | null {
  const idx = args.indexOf(flag);
  if (idx === -1 || idx === args.length - 1) return null;
  return args[idx + 1] ?? null;
}

// ---------------------------------------------------------------------------
// Main entry
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const subcommand = args[0];

  switch (subcommand) {
    case 'list-reports': {
      const stateFilter = extractFlagValue(args, '--state');
      await cmdListReports(stateFilter);
      break;
    }

    case 'touch': {
      const reportId = args[1];
      if (!reportId) {
        console.error('Missing <reportId>');
        console.error('Usage: moderation touch <reportId> [--operator <userId>]');
        process.exit(1);
      }
      const operatorUserId = parseOperator(args);
      if (!operatorUserId) {
        console.error(
          'Missing operator identity: pass --operator <userId> or set TRIBELY_OPERATOR_USER_ID',
        );
        process.exit(1);
      }
      await cmdTouch(reportId, operatorUserId);
      break;
    }

    case 'resolve': {
      const reportId = args[1];
      if (!reportId) {
        console.error('Missing <reportId>');
        console.error(
          'Usage: moderation resolve <reportId> --hide|--keep --reason <text> [--operator <userId>]',
        );
        process.exit(1);
      }
      const isHide = args.includes('--hide');
      const isKeep = args.includes('--keep');
      if (isHide === isKeep) {
        console.error('Pass exactly one of --hide / --keep');
        process.exit(1);
      }
      const reason = extractFlagValue(args, '--reason');
      if (!reason) {
        console.error('Missing --reason <text>');
        process.exit(1);
      }
      const overrideReason = extractFlagValue(args, '--override-reason');
      const operatorUserId = parseOperator(args);
      if (!operatorUserId) {
        console.error(
          'Missing operator identity: pass --operator <userId> or set TRIBELY_OPERATOR_USER_ID',
        );
        process.exit(1);
      }
      await cmdResolve(reportId, isHide, reason, operatorUserId, overrideReason);
      break;
    }

    case 'sweep-resolved-reports': {
      await cmdSweepResolvedReports();
      break;
    }

    case 'cancel-event-for-safety': {
      const eventId = args[1];
      if (!eventId) {
        console.error('Missing <eventId>');
        console.error(
          'Usage: moderation cancel-event-for-safety <eventId> --reason=safety --justification "<text>" [--report-id <reportId>] [--operator <userId>]',
        );
        process.exit(1);
      }
      // --reason must be present and equal to the literal string "safety".
      // Support both --reason=safety and --reason safety forms.
      const reason =
        extractFlagValue(args, '--reason') ??
        args.find((a) => a.startsWith('--reason='))?.slice('--reason='.length) ??
        null;
      if (reason !== 'safety') {
        console.error('Missing or invalid --reason: only --reason=safety is supported');
        process.exit(1);
      }
      const justification = extractFlagValue(args, '--justification');
      if (!justification || justification.trim().length === 0) {
        console.error('Missing --justification "<text>"');
        process.exit(1);
      }
      const reportId = extractFlagValue(args, '--report-id');
      const operatorUserId = parseOperator(args);
      if (!operatorUserId) {
        console.error(
          'Missing operator identity: pass --operator <userId> or set TRIBELY_OPERATOR_USER_ID',
        );
        process.exit(1);
      }
      await cmdCancelEventForSafety(eventId, justification, reportId, operatorUserId);
      break;
    }

    case 'escalate': {
      const reportId = args[1];
      if (!reportId) {
        console.error('Missing <reportId>');
        console.error(
          'Usage: moderation escalate <reportId> --category <criminal-content|imminent-harm|ambiguous-policy|external-jurisdiction> --external-ref "<text>" [--note "<text>"] [--operator <userId>]',
        );
        process.exit(1);
      }
      const validCategories = [
        'criminal-content',
        'imminent-harm',
        'ambiguous-policy',
        'external-jurisdiction',
      ];
      const category = extractFlagValue(args, '--category');
      if (!category || !validCategories.includes(category)) {
        console.error(
          'Invalid --category: must be one of criminal-content, imminent-harm, ambiguous-policy, external-jurisdiction',
        );
        process.exit(1);
      }
      const externalRef = extractFlagValue(args, '--external-ref');
      if (!externalRef || externalRef.trim().length === 0) {
        console.error('External reference required (--external-ref "<text>")');
        process.exit(1);
      }
      const note = extractFlagValue(args, '--note');
      const operatorUserId = parseOperator(args);
      if (!operatorUserId) {
        console.error(
          'Missing operator identity: pass --operator <userId> or set TRIBELY_OPERATOR_USER_ID',
        );
        process.exit(1);
      }
      await cmdEscalate(reportId, category, externalRef, note, operatorUserId);
      break;
    }

    case 'record-external-input': {
      const reportId = args[1];
      if (!reportId) {
        console.error('Missing <reportId>');
        console.error(
          'Usage: moderation record-external-input <reportId> --source <counsel|partner|imda|other> --disposition "<text>" --received-at <ISO8601> [--operator <userId>]',
        );
        process.exit(1);
      }
      const validSources = ['counsel', 'partner', 'imda', 'other'];
      const source = extractFlagValue(args, '--source');
      if (!source || !validSources.includes(source)) {
        console.error('Invalid --source: must be one of counsel, partner, imda, other');
        process.exit(1);
      }
      const disposition = extractFlagValue(args, '--disposition');
      if (!disposition || disposition.trim().length === 0) {
        console.error(
          'Usage: moderation record-external-input <reportId> --source <counsel|partner|imda|other> --disposition "<text>" --received-at <ISO8601> [--operator <userId>]',
        );
        process.exit(1);
      }
      const receivedAtRaw = extractFlagValue(args, '--received-at');
      if (!receivedAtRaw) {
        console.error('Missing --received-at (must be ISO8601, e.g. 2026-05-26T10:30:00Z)');
        process.exit(1);
      }
      const receivedAt = new Date(receivedAtRaw);
      if (isNaN(receivedAt.getTime())) {
        console.error('Invalid --received-at (must be ISO8601, e.g. 2026-05-26T10:30:00Z)');
        process.exit(1);
      }
      const operatorUserId = parseOperator(args);
      if (!operatorUserId) {
        console.error(
          'Missing operator identity: pass --operator <userId> or set TRIBELY_OPERATOR_USER_ID',
        );
        process.exit(1);
      }
      await cmdRecordExternalInput(reportId, source, disposition, receivedAt, operatorUserId);
      break;
    }

    case 'show': {
      const reportId = args[1];
      if (!reportId) {
        console.error('Missing <reportId>');
        console.error('Usage: moderation show <reportId>');
        process.exit(1);
      }
      await cmdShow(reportId);
      break;
    }

    default: {
      console.error(`Unknown subcommand: ${subcommand ?? '(none)'}`);
      console.error(
        'Valid: list-reports | touch | resolve | cancel-event-for-safety | sweep-resolved-reports | escalate | record-external-input | show',
      );
      process.exit(1);
    }
  }

  process.exit(0);
}

main().catch((err) => {
  console.error('moderation CLI failed:', err);
  process.exit(1);
});
