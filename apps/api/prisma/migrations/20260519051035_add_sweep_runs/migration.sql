-- TRI-79 Brief 2: sweep_runs observability table
-- One row per scheduled sweep execution (success or failure).
-- Answers "did the sweep run on date X?" for App Store / regulator audit requests.
-- `kind` is open-ended so future sweep jobs can reuse this table.

-- CreateTable
CREATE TABLE "sweep_runs" (
    "id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "finishedAt" TIMESTAMP(3),
    "evaluated" INTEGER NOT NULL DEFAULT 0,
    "deleted" INTEGER NOT NULL DEFAULT 0,
    "failed" INTEGER NOT NULL DEFAULT 0,
    "reaperRetried" INTEGER NOT NULL DEFAULT 0,
    "reaperSucceeded" INTEGER NOT NULL DEFAULT 0,
    "error" TEXT,

    CONSTRAINT "sweep_runs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "sweep_runs_kind_startedAt_idx" ON "sweep_runs"("kind", "startedAt");
