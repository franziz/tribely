#!/usr/bin/env tsx
// Operator moderation CLI — stop-gap. Retired by TRI-159 (HTTP admin commands).
//
// Usage:
//   npm run --workspace=@tribely/api moderation list-reports
//   npm run --workspace=@tribely/api moderation touch <reportId> [--operator <userId>]
//   npm run --workspace=@tribely/api moderation resolve <reportId> --hide --reason <text> [--operator <userId>]
//   npm run --workspace=@tribely/api moderation resolve <reportId> --keep --reason <text> [--operator <userId>]
//
// Operator identity: --operator flag OR $TRIBELY_OPERATOR_USER_ID env var.
// list-reports does not require an operator identity (read-only command).

import { buildContainer } from '@/core/di/container.js';
import { runAsSystem } from '@/core/context/system-context.js';
import type { Report } from '@/features/reports/domain/entities/report.js';
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
  | 'BREACH-7D';

/**
 * Compute the SLA flag for a single unresolved report.
 *
 * Precedence (most severe wins):
 *   BREACH-7D           ageHours >= SLA_HARD_CEILING_HOURS
 *   APPROACHING-7D      ageHours >= APPROACHING_HARD_CEILING_HOURS
 *   OVERDUE-72H         ageHours >= SLA_FIRST_TOUCH_HOURS && firstReviewedAt === null
 *   APPROACHING-72H     ageHours >= APPROACHING_FIRST_TOUCH_HOURS && firstReviewedAt === null
 *   OK                  otherwise
 */
const computeSlaFlag = (report: Report, now: Date): SlaFlag => {
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

async function cmdListReports(): Promise<void> {
  const container = buildContainer();

  await runAsSystem('cli.moderation.list-reports', async () => {
    const now = new Date();

    // Compute SLA thresholds.
    const approachingFirstTouchBefore = new Date(
      now.getTime() - APPROACHING_FIRST_TOUCH_HOURS * 60 * 60 * 1000,
    );
    const approachingHardCeilingBefore = new Date(
      now.getTime() - APPROACHING_HARD_CEILING_HOURS * 60 * 60 * 1000,
    );
    const hardCeilingBefore = new Date(
      now.getTime() - SLA_HARD_CEILING_HOURS * 60 * 60 * 1000,
    );

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

    // Compute SLA flags per row.
    const rows = allReports.map((r) => ({
      report: r,
      flag: computeSlaFlag(r, now),
    }));

    // Count banners using the SLA bucket queries.
    // "approaching 72h" = open for >=48h (older than approachingFirstTouchBefore)
    //   but not yet >=7d and firstReviewedAt null.
    const approaching72hReports = approachingFirstTouch.filter(
      (r) => r.firstReviewedAt === null && computeSlaFlag(r, now) === 'APPROACHING-72H',
    );
    const breach7dCount = breach7d.length;
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
      console.log('No unresolved reports.');
      return;
    }

    // Print table header.
    const COL_ID = 26;
    const COL_REPORTER = 28;
    const COL_TARGET = 28;
    const COL_REASON = 14;
    const COL_CREATED = 17;
    const COL_AGE = 6;
    const COL_SLA = 16;
    const COL_FIRST_REVIEWED = 17;

    const header = [
      padRight('ID', COL_ID),
      padRight('Reporter', COL_REPORTER),
      padRight('Target', COL_TARGET),
      padRight('Reason', COL_REASON),
      padRight('Created', COL_CREATED),
      padRight('Age', COL_AGE),
      padRight('SLA Flag', COL_SLA),
      padRight('First-Reviewed', COL_FIRST_REVIEWED),
    ].join(' | ');

    const separator = '-'.repeat(header.length);

    console.log(header);
    console.log(separator);

    for (const { report: r, flag } of rows) {
      const row = [
        padRight(truncate(r.id, COL_ID), COL_ID),
        padRight(truncate(r.reporterUserId, COL_REPORTER), COL_REPORTER),
        padRight(
          truncate(`${r.target.type}:${r.target.id}`, COL_TARGET),
          COL_TARGET,
        ),
        padRight(truncate(r.reason.value, COL_REASON), COL_REASON),
        padRight(formatDate(r.createdAt), COL_CREATED),
        padRight(formatAge(r, now), COL_AGE),
        padRight(flag, COL_SLA),
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
): Promise<void> {
  const container = buildContainer();
  const action = isHide ? 'resolve_hidden' : ('resolve_kept' as const);
  const systemLabel = isHide ? 'cli.moderation.resolve-hidden' : 'cli.moderation.resolve-kept';

  console.log(`Acting as ${operatorUserId}`);
  await runAsSystem(systemLabel, async () => {
    await container.performModerationActionUseCase.execute({
      action,
      reportId,
      operatorUserId,
      reason,
    });
  });

  if (isHide) {
    console.log(`Resolved report ${reportId} (hidden)`);
  } else {
    console.log(`Resolved report ${reportId} (kept)`);
  }
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
      await cmdListReports();
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
      const operatorUserId = parseOperator(args);
      if (!operatorUserId) {
        console.error(
          'Missing operator identity: pass --operator <userId> or set TRIBELY_OPERATOR_USER_ID',
        );
        process.exit(1);
      }
      await cmdResolve(reportId, isHide, reason, operatorUserId);
      break;
    }

    default: {
      console.error(`Unknown subcommand: ${subcommand ?? '(none)'}`);
      console.error('Valid: list-reports | touch | resolve');
      process.exit(1);
    }
  }

  process.exit(0);
}

main().catch((err) => {
  console.error('moderation CLI failed:', err);
  process.exit(1);
});
