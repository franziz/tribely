---
name: work-on-issue
description: CROSS-STACK orchestrator script. Deliver a Linear issue end-to-end via the multi-agent workflow — branch creation, PM framing + CEO sign-off, EL technical spec, SWE implementation (parallelizable), architecture-reviewer + qa loops reporting back to EL, then `/github-pr`. Orchestrator-only — must NEVER be invoked from inside a sub-agent. Spawns specialized agents at each step; the skill itself never edits code, writes to Linear, or runs project commands directly.
---

# /work-on-issue

```
/work-on-issue <issue-id>             # e.g. /work-on-issue TRI-44
/work-on-issue <issue-id> --skip-ceo  # bypass CEO sign-off (tooling/refactor only — justify to user)
/work-on-issue <issue-id> --resume    # pick up an in-flight workflow (branch already exists)
```

**Caller scope:** orchestrator (main loop) ONLY. Sub-agents must NOT invoke this skill — it coordinates them, not the other way around. If a sub-agent tries to call it, refuse and route the request back to the orchestrator.

**Linear scope:** Tribely team ONLY (id `d44b93db-4bdc-4531-966b-81058ba01a5a`). If the supplied issue id resolves to a different team, refuse and ask the user to clarify.

## Hard constraints (read first)

These are **non-negotiable**:

- **Orchestrator never edits files, never runs `npm`/`flutter`/`prisma`/migrations, never writes to Linear, never commits.** All execution is delegated. The orchestrator's job is routing, relaying, and gating.
  - **Even in the qa loop, the orchestrator does not run `format:check` / `analyze` / `test` / `lint` directly after a SWE fix.** Either trust SWE's inline verification (SWE typically runs these locally before reporting) or re-spawn `qa` to confirm clean. Read-only `git status` / `git log` / `git diff` for routing decisions is fine; npm/flutter invocations are not.
- **Branch-first is mandatory.** Step 1 (branch creation) MUST complete before any agent that produces code is spawned. No exceptions.
- **`software-engineer` is never spawned directly by the orchestrator.** SWE invocations are scoped by `engineering-lead`'s technical brief — EL owns the WHO/WHAT/HOW of each SWE task. The orchestrator may spawn multiple SWE agents in parallel based on EL's plan, but each SWE prompt is EL's brief, not the orchestrator's improvisation.
- **Linear writes are `product-manager`'s territory only.** EL, SWE, reviewer, qa MUST NOT write to Linear. If EL identifies follow-up work, they surface it to PM (via the orchestrator) for PM to file.
- **Architecture-reviewer and qa report to EL via the orchestrator.** Without Agent Teams, there is no direct messaging — orchestrator relays. EL decides what's fix-now vs. fix-followup vs. accept-with-rationale.
- **CEO is consulted for strategic alignment, not technical review.** Anything that could pull Tribely outside Singapore-only / English-only / no-payments / mobile-first MUST hit CEO before EL. Pure tech-debt or refactors with no user-facing surface may use `--skip-ceo` (justify in the relay).
- **Stop on disagreement.** PM↔CEO scope conflict, PM↔EL feasibility conflict, reviewer/EL ruling disputes → orchestrator stops, relays both views, waits for user direction. Never pick a side.
- **No auto-merge.** `/github-pr` opens the PR; merging is a human decision.

## Procedure

### 1. Read the issue + create the branch (orchestrator)

The only step the orchestrator executes directly. No sub-agents yet.

1. Call `mcp__plugin_linear_linear__get_issue` with the supplied id. Verify the issue's `team.id` matches the Tribely team id. If not → refuse.
2. Read the issue body to determine branch type prefix:
   - `feat/` — new user-facing capability
   - `fix/` — bug fix
   - `chore/` — tooling, docs, dependencies, infra
   - `refactor/` — internal refactor with no behavior change
3. Build a 3–5 word kebab-case slug from the issue title (drop articles, lowercase).
4. Verify `main` is clean: `git status` shows nothing uncommitted. If dirty → refuse and ask user to stash or commit.
5. Create + checkout the branch from latest `main`:
   ```bash
   git checkout main && git pull --ff-only && git checkout -b <type>/TRI-XX-<slug>
   ```
6. Emit Step 1 status (see "Outputs at each step").

If `--resume` was passed: skip 4–5, verify the expected branch exists, checkout it, and resume from the first incomplete step (ask the user where the prior run left off).

### 2. Product framing (spawn `product-manager`)

Spawn `product-manager` with a self-contained prompt containing:

- The Linear issue id and full issue body (don't make PM re-fetch unless needed).
- Instruction: decompose into user-observable acceptance criteria, explicit non-goals, dependencies, and open questions. Apply the Singapore-launch scope filter. Flag anything that warrants CEO sign-off.

PM returns a product brief. Orchestrator relays the brief to the user verbatim (or near-verbatim) and proceeds.

If PM determines the issue is too large for one cycle and proposes splitting → orchestrator stops, surfaces the split proposal to the user, and waits. Do NOT run step 4+ against an unsplit overscope.

### 3. CEO strategic sign-off (spawn `ceo`)

Spawn `ceo` with PM's brief. CEO's job: verdict from the Singapore-launch lens.

Possible verdicts:
- **aligned** → proceed to step 4.
- **aligned-with-conditions** → re-spawn `product-manager` to fold the conditions into the acceptance criteria, then proceed to step 4 with the updated brief.
- **misaligned-redirect** → orchestrator stops, relays CEO's verdict + proposed strategic alternative to the user, waits. Do NOT proceed to EL without alignment.

`--skip-ceo` bypasses this step. Only acceptable when the issue has no strategic surface (pure tech debt, dependency bump, internal refactor). Document the bypass reason in the Step 3 relay.

### 4. Technical specification (spawn `engineering-lead`)

Spawn `engineering-lead` with:

- The original issue id.
- PM's product brief (acceptance criteria + non-goals + dependencies).
- CEO's verdict and any conditions.

EL's job:

- Translate product → technical requirements (NFRs, data model, integration points, technical non-goals).
- Apply the YAGNI test before introducing new abstractions.
- Decompose into a phased technical approach and identify parallelizable sub-tasks.
- Produce one structured brief per SWE sub-task. Each brief MUST include: scope, target files/modules, acceptance-criteria slice, technical non-goals, dependencies on other sub-tasks, suggested scaffolding skills (`/api-new-*`, `/mobile-new-*`).

Orchestrator relays EL's plan + the sub-task briefs to the user, then proceeds.

If EL's feasibility read conflicts materially with PM's scope (e.g., "this is XL, PM committed it to a 1-cycle slice") → orchestrator stops, surfaces both views to the user, waits.

### 5. Implementation (spawn `software-engineer` per EL sub-task)

For each sub-task in EL's plan:

- Spawn `software-engineer` with EL's per-task brief as the prompt (verbatim, no editorializing by the orchestrator).
- **Independent sub-tasks run in parallel** — emit a single message containing multiple Agent tool calls.
- **Dependent sub-tasks run sequentially** — wait for the dependency to report complete before spawning the dependent.

SWE's job per sub-task:

- Implement via the appropriate scaffolding skills.
- Stage commits via `/github-commit`, split by logical scope (feature vs. tooling vs. CLAUDE.md edits) per the orchestrator rule in CLAUDE.md.
- Report: files changed, commits made, any deviation from the brief, any clarifying questions.

If SWE asks a clarifying question:

- Product-side question → route to PM (re-spawn briefly with the specific question).
- Technical-side question → route to EL.
- Resume SWE with the answer.

### 6. Architecture review (spawn `architecture-reviewer`)

Once SWE reports complete on all sub-tasks, spawn `architecture-reviewer`. The reviewer runs:

- `/api-review-architecture` if `apps/api/**` changed.
- `/mobile-review-architecture` if `apps/mobile/**` changed.
- Both if cross-stack.

Reviewer returns a violations report (file:line, severity, rule). Reviewer NEVER edits code.

Orchestrator relays the report to EL (re-spawn EL with the report). EL's response per violation:

- **fix-now** → re-brief SWE to fix in the current branch.
- **fix-followup-issue** → EL drafts a follow-up note; orchestrator queues a step-9 PM action to file the issue.
- **accept-with-rationale** → EL writes a one-line rationale; orchestrator captures it for the PR description.

Loop steps 5–6 until reviewer is clean (no `error`-severity findings) OR EL has signed off on remaining items.

### 7. QA (spawn `qa`)

Spawn `qa` to run the project's test scripts on the touched surfaces:

- Backend changes → `format:check`, `typecheck`, `lint`, `test` on `@tribely/api`.
- Mobile changes → `mobile:format:check`, `mobile:analyze`, `mobile:test`.

QA returns pass/fail per script with failure excerpts. QA NEVER edits code.

Orchestrator relays failures to EL. EL re-briefs SWE on each failure. Loop steps 5–7 until QA passes clean.

The orchestrator does NOT run test scripts between SWE fix cycles to "double-check" before re-spawning qa — see the Hard constraints above.

**Escalation:** if the same QA failure persists across 3 SWE fix cycles, qa flags `escalate=true`. Orchestrator surfaces to the user with EL's options (refactor, accept-with-rationale, split to follow-up). Do NOT silently keep retrying.

### 8. PR creation (orchestrator invokes `/github-pr`)

Once reviewer and qa are both clean:

1. Verify working tree is clean (`git status`), commits are pushed, branch is up to date with `main` (rebase if needed — delegate to `software-engineer` if rebase produces conflicts).
2. Invoke the `/github-pr` skill. The skill auto-detects the Linear issue from the branch name.
3. In the PR description, include EL's accept-with-rationale notes from step 6 (if any).
4. Output the PR URL to the user.

### 9. Linear update (spawn `product-manager`)

Final PM spawn:

- **Target status:** Call `mcp__plugin_linear_linear__get_issue` before issuing any state change. If the PR is still open, move the issue to "In Review". If the PR has already been merged (e.g., Linear's GitHub integration auto-completed the issue, or the user merged before step 9 ran), confirm the status is "Done" and skip the transition — do NOT regress from "Done" to "In Review".
- Comment the PR URL on the issue.
- File any follow-up issues EL queued in step 6 (`fix-followup-issue` items).

Orchestrator emits the final Step 9 summary and stops.

## Outputs at each step

After each step, the orchestrator emits a structured status update to the user:

```
Step <N>/9 — <step name>
  Agent: <agent-name or "orchestrator">
  Verdict: <one-line verdict>
  Next: <one-line next-step preview, or "blocked: <reason>">
```

Keep updates terse. The user reads these to track a long workflow without reading every agent transcript.

## Failure modes and recovery

| Failure | Action |
|---|---|
| Issue not in Tribely team | Refuse. Ask user to verify the id. |
| `main` is dirty at step 1 | Refuse. Ask user to stash/commit before starting. |
| Branch already exists | Ask user: reuse via `--resume`, or pick a different slug. |
| PM proposes split (issue too large) | Stop. Relay split to user. Do not proceed. |
| CEO misaligned-redirect | Stop. Relay verdict + alternative. Wait for direction. |
| PM↔EL feasibility/scope conflict | Stop. Relay both views. Do not pick a side. |
| SWE clarifying question | Pause SWE. Route to PM (product-side) or EL (technical-side). Resume with the answer. |
| Reviewer/QA loops 3× without progress | Escalate to EL. Surface EL's options to user. |
| Rebase conflict before PR | Delegate to `software-engineer` to resolve. If non-trivial, surface to user. |
| PATH-missing CLI (`gh`, `flutter`, `npm`) | Report to user. Do not hunt absolute paths in `/opt/homebrew/bin/`, `/usr/local/bin/`, etc. |
| `/github-pr` fails (auth, network) | Surface to user with the gh error. Do not retry blindly. |

## Edge cases

- **Pure spike / research issue.** Use a `chore/` branch. Skip steps 5–7 (no implementation, no review, no qa). PM closes the issue in step 9 with the findings.
- **Cross-cutting refactor with no Linear issue.** This skill requires an issue id. Route to PM via `/linear-techdebt` to file one first, then re-invoke `/work-on-issue` with the new id.
- **Hotfix on production.** The full 9-step workflow is overkill. Use a streamlined path: PM frames briefly → EL gives the fix shape → SWE implements → qa runs → PR. Skip steps 3 (CEO) and 6 (reviewer) if the fix is mechanical and reviewer-clean by construction. Document the skipped steps in the PR description.
- **Multiple issues in one branch.** Discouraged — splits review scope. If the user insists, run steps 2–4 separately per issue and merge the EL plans before step 5. The branch name uses the lead issue id; the PR body references all of them.
- **Re-spawn of an agent within a step.** Allowed and expected (e.g., re-spawning EL with the reviewer report). Each spawn gets a self-contained prompt — agents have no memory of prior spawns unless Agent Teams + SendMessage is in use.

## What this skill is NOT

- **Not an agent.** It's a procedural script the orchestrator follows.
- **Not a substitute for thinking.** The orchestrator still applies judgment at each step's verdict — relaying briefs, asking the user when blocked, choosing parallel vs. sequential SWE spawns from EL's plan.
- **Not a one-shot.** Steps 5–7 loop. The orchestrator must hold state across the loop (what failures are open, what fixes are pending) and surface concise progress to the user.

## Important

This skill orchestrates the multi-agent workflow defined in `CLAUDE.md` → "Agent orchestration & role boundaries". If those role boundaries change, update this skill in lockstep. The skill is the choreography; CLAUDE.md is the why.
