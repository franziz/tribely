---
name: work-on-issue
description: CROSS-STACK orchestrator script. Deliver an *engineering* Linear issue end-to-end via the multi-agent workflow, coordinated as an Agent Team — confirm the ticket is an engineering ticket, branch + team creation, PM framing + CEO sign-off, optional UI/UX design, EL technical spec, SWE implementation (parallelizable), architecture-reviewer + qa loops, `/github-pr`, PM Linear update, then an end-of-cycle `/learn` reflection. Role agents are spawned ONCE as named team members and re-engaged via SendMessage with their context intact — no re-stating briefs every cycle. Orchestrator-only — must NEVER be invoked from inside a sub-agent. The skill itself never edits code, writes to Linear, or runs project commands directly.
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
- **Coordination model — one Agent Team per issue, persistent named teammates.** This workflow runs as an Agent Team (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is enabled for this project), not a series of throwaway sub-agent spawns. Step 1 creates the team; each role agent is spawned ONCE as a named team member (`pm`, `ceo`, `el`, `swe-a`/`swe-b`/…, `reviewer`, `qa`, and conditionally `designer`) and re-engaged thereafter via `SendMessage({to: "<name>"})`. A teammate retains its full context across re-engagements within the live session — so a re-engagement carries only the *delta* (the reviewer report, the qa failure, the CEO condition), NOT a re-stated brief. This is the core win over the old re-spawn model: EL doesn't get its technical plan re-fed every cycle, an in-flight SWE doesn't lose its working state when answered, and PM's Linear queue stays in sync because rulings reach it the moment they land. `SendMessage` is async/queued, not live — send, then the teammate wakes, works, replies automatically, and goes idle; do NOT poll or sleep, the harness delivers the reply as a new turn. Teammates going idle between turns is normal, not "done" or "stuck." **Deliverable-before-idle contract:** every spawn prompt and re-engagement MUST state that the teammate's turn is not complete until it has sent its full deliverable via `SendMessage` to team-lead — a teammate's plain-text output is invisible to the team, so work finished but not messaged is work lost. Correspondingly, when an idle notification arrives with NO deliverable message, the orchestrator immediately nudges that teammate to emit it (a one-line "send your deliverable per your spawn instructions" message) — this is normal recovery, not an error, but each missed deliverable costs a full round-trip, which is why the spawn-prompt contract exists. **Caveat — context is session-bound:** if the session/process ends, teammates and their context are gone; `--resume` must recreate the team and rebuild context from the issue + branch state (see Edge cases). **Role boundaries still bind:** the team can technically message peer-to-peer, but the orchestrator stays the gate — it relays decisions, enforces "PM never sees code," and owns user-facing status. Agents still emit self-contained replies to the orchestrator (their agent files require it); teams change *re-engagement*, not the reply contract. The team is torn down in Step 11.
- **Initial teammate spawns MUST set `run_in_background: true`; re-engagement uses `SendMessage` (inherently async).** No exceptions on the spawn flag — applies to the first spawn of PM, CEO, designer, EL, every SWE, architecture-reviewer, and qa. Rationale: agent runs are long (often minutes to hours of wall time), and foreground spawns block the orchestrator's context on a stalled tool call while the user has no way to interject. Backgrounded spawns let the orchestrator emit status to the user, accept new instructions, and resume on the completion notification. The harness auto-notifies on completion — do NOT poll or sleep. Sequential dependencies still work: spawn (or `SendMessage`) the next step when the prior teammate's completion/idle notification arrives. Parallel spawns in one message remain the right pattern for independent work; they just all run in background.
- **`software-engineer` is never spawned directly by the orchestrator.** SWE invocations are scoped by `engineering-lead`'s technical brief — EL owns the WHO/WHAT/HOW of each SWE task. The orchestrator may spawn multiple SWE agents in parallel based on EL's plan, but each SWE prompt is EL's brief, not the orchestrator's improvisation.
- **Linear writes are `product-manager`'s territory only.** EL, SWE, reviewer, qa MUST NOT write to Linear. If EL identifies follow-up work, they surface it to PM (via the orchestrator) for PM to file.
- **PM never sees code-level data.** Stack traces, file paths, function names, code shape, and technical hypotheses go to `engineering-lead` first — never direct to PM. When a smoke-test failure, exception, or any code-rooted issue surfaces, the routing is: orchestrator → EL (technical diagnosis + translation to product-framed summary: launch-impact, fix scope) → orchestrator → PM (with EL's product framing, NOT the stack trace) → PM rules path → orchestrator → EL briefs SWE → SWE implements. Putting PM in the code domain forces hypothesis errors EL then has to correct. PM owns triage in product terms (launch-blocker vs. defer, AC in user-observable terms, Linear scoping); EL owns diagnosis.
- **After ANY SWE fix cycle that touches code, architecture-reviewer AND qa must re-run before advancing to Step 8.5 or Step 9.** No skipping the re-run because "the change looks small" or "tests passed locally." The orchestrator does not get to advance to manual smoke or PR creation directly off a SWE commit — both verification agents (`reviewer` and `qa`, re-engaged via `SendMessage`) must re-run and report clean (or surface findings that EL adjudicates) every cycle. This applies even to whitespace-only / format-only commits in code files — the cost of running them is small; the cost of shipping an unverified regression is high.
  - **Narrow exception — pure-documentation commits.** If the SWE commit's changed-files set is entirely `*.md` (or other non-executable text — no `.ts` / `.tsx` / `.dart` / `.prisma` / `package.json` / `pubspec.yaml` / config), reviewer + qa re-run is NOT required. There is no architecture surface to review and no test surface to run. This applies to design-spike spec commits, policy-doc commits, and similar markdown-only deliverables. Verify the file set with `git diff --name-only` before invoking the exception; if any non-`.md` file is present, the full re-run rule applies.
  - **Narrow exception — pure test-harness commits with no cross-boundary import surface.** This exception is narrower than it once read. The architecture-review skills do NOT blanket-exclude test files: `/api-review-architecture` filters to `apps/api/src/**/*.ts` (which *includes* `*.test.ts`) and only puts test *quality/coverage* out of scope — a test file can still carry an in-scope architecture violation (a cross-feature import, infrastructure reached into a feature, an A11/A13-class layering breach). So reviewer re-run may be skipped ONLY when BOTH hold: (a) the SWE commit's changed-files set is entirely test files (`*.test.ts` / `*_test.dart` / `*.spec.ts` / under `test/`), AND (b) the diff introduces NO new cross-boundary import — no new cross-feature import, no new feature→another-feature reach, no infrastructure-into-domain import. A pure test-harness change (fixture/setup/teardown/assertion edits, e.g. adding a teardown disconnect, importing shared `core/*` infra into a test) clears both and may skip reviewer. **If the test diff adds any cross-feature / cross-layer import, run reviewer** — that is exactly what it would catch. Verify BOTH conditions with `git diff` (not just `git diff --name-only`) before invoking; when in doubt, run reviewer. **qa re-run ALWAYS applies** — qa is the verification for a test fix; this exception skips reviewer only, never qa. NOTE: the `engineering-lead` agent file (line ~44) deliberately instructs EL to NEVER pre-bless skipping reviewer in its brief, including for test-only commits — that stands. The skip is the **orchestrator's** narrow judgment call at Step 7 after inspecting the actual diff, not a license EL grants in advance. (Precedent: TRI-271 — a one-line `prisma.$disconnect()` teardown in an `*.integration.test.ts` file, importing only shared `core/db/prisma`; both conditions held, reviewer skipped.)
- **Architecture-reviewer and qa report to the orchestrator, which relays to EL via `SendMessage`.** `el` is a persistent teammate that already holds the technical plan, so the relay carries only the findings — not the plan. EL decides what's fix-now vs. fix-followup vs. accept-with-rationale; fix-now items go to the relevant `swe-*` teammate via `SendMessage` (which preserves that SWE's in-progress state). Peer-to-peer reviewer→EL messaging is technically available under the team, but the orchestrator stays in the loop so role boundaries and user-facing relays hold.
- **CEO is consulted for strategic alignment, not technical review.** Anything that could pull Tribely outside Singapore-only / English-only / no-payments / mobile-first MUST hit CEO before EL. Pure tech-debt or refactors with no user-facing surface may use `--skip-ceo` (justify in the relay).
- **`ui-ux-designer` is consulted ONLY when the issue has user-facing UI/UX design surface that needs design decisions** — new screens/flows, significant layout or hierarchy changes, design-system additions, or competitor-aware UX evaluation. It produces design specifications, NOT code. Skip the step entirely for pure backend work, tooling, infra, refactors with no user-visible surface, or UI work that just follows an already-specified design. PM flags the need in step 2; orchestrator gates step 4 on that flag.- **Stop on disagreement.** PM↔CEO scope conflict, PM↔EL feasibility conflict, designer↔EL design-vs-technical conflict, reviewer/EL ruling disputes → orchestrator stops, relays both views, waits for user direction. Never pick a side.
- **"CPO" or other unassigned-role questions from sub-agents must be split by domain.** When a designer flags "CPO consultation needed," a PM brief surfaces an "open question for CPO," or any sub-agent uses "CPO" (or any role not in the agent roster) as a placeholder addressee, the orchestrator MUST decompose the question by domain before surfacing — strategic / launch-funnel implications → `ceo`; UX pattern / design-system additions → `ui-ux-designer`; technical feasibility → `engineering-lead`. Do NOT lump the question to the user as "CPO question to you." The repo owner may wear those hats personally, but the orchestration value of agent routing is getting each domain its dedicated reasoner before the user synthesizes. Lumping bypasses the structure the workflow exists to provide.
- **When CEO / designer / EL produces a ruling that affects PM's Linear queue, orchestrator MUST `SendMessage` the `pm` teammate in the moment — not just relay to the user.** Any ruling that creates follow-up tickets, tightens AC, transitions status, or alters Step 10 ticket plans must reach `pm` via `SendMessage` as it lands. Because `pm` is persistent, each such message accretes onto its live queue — so by Step 10 PM already holds every ruling and doesn't re-derive scope from a stale state. Relaying only to the user reintroduces the out-of-sync backlog the team model is meant to eliminate. The user is the audience for status updates; `pm` is the operational handler.
- **No auto-merge.** `/github-pr` opens the PR; merging is a human decision.

## Procedure

### 1. Read the issue, confirm it's an engineering ticket, create the branch + team (orchestrator)

The only setup step the orchestrator executes directly. No teammates yet.

1. Call `mcp__plugin_linear_linear__get_issue` with the supplied id. Verify the issue's `team.id` matches the Tribely team id. If not → refuse.
2. **Engineering-ticket guard.** Read the body + labels and classify before spending any setup. This skill delivers *engineering* work — it must have AT LEAST ONE of: a code/repo deliverable (source, migration, config, CI), a repo-committed artifact the build pipeline produces (design spec, policy doc, runbook markdown), or a technical surface `el`/`swe`/`reviewer`/`qa` act on. If the ticket has NONE of these — pure strategy, partnership / business development, hiring, marketing copy living in an external tool, community ops, fundraising, event logistics — it is a **non-engineering ticket**: refuse before creating any branch or team, and route it to its real owner (strategic / launch-funnel → `ceo`; product / backlog shaping → `product-manager`; anything else — surface to the user). Do NOT spin up the build pipeline for it. If the classification is genuinely ambiguous, surface a one-line read to the user and wait for a confirm rather than guessing. (Design-only, spike/research, policy-doc, and runbook tickets DO pass this guard — they produce repo artifacts and have their own paths in Edge cases. PM's Step 2 brief is a second checkpoint: if PM reports no engineering deliverable, the orchestrator stops here and routes per above.)
3. Determine the branch type prefix from the body:
   - `feat/` — new user-facing capability
   - `fix/` — bug fix
   - `chore/` — tooling, docs, dependencies, infra
   - `refactor/` — internal refactor with no behavior change
4. Build a 3–5 word kebab-case slug from the issue title (drop articles, lowercase).
5. Verify `main` is clean: `git status` shows nothing uncommitted. If dirty → refuse and ask user to stash or commit.
6. Create + checkout the branch from latest `main`:
   ```bash
   git checkout main && git pull --ff-only && git checkout -b <type>/TRI-XX-<slug>
   ```
7. **Create the Agent Team** for this workflow: `TeamCreate({team_name: "tri-XX-<slug>", description: "Deliver TRI-XX end-to-end"})` (team name kebab-case, ≤64 chars). Every role agent in later steps is spawned into this team with a stable `name` and re-engaged via `SendMessage`. The team is torn down in Step 11.
8. Emit Step 1 status (see "Outputs at each step").

If `--resume` was passed: skip 5–6, verify the expected branch exists, and check it out. For the team — if the prior session is still live and the team exists, reuse it; if the session ended (teammates and their context are gone), recreate it via `TeamCreate` and re-spawn only the teammates the remaining steps need, rebuilding their context from the issue body + branch diff. Then resume from the first incomplete step (ask the user where the prior run left off).

### 2. Product framing (spawn `product-manager`)

Spawn `product-manager` into the team as `pm` (first spawn — full self-contained prompt) containing:

- The Linear issue id and full issue body (don't make PM re-fetch unless needed).
- Instruction: **move the issue to "In Progress" as the first action** — PM taking the ticket IS the start of active work, and the board should reflect that from the moment the cycle begins, not retroactively at PR time. This is PM's one sanctioned Linear write at this step (the Linear-writes-are-PM-only constraint holds; the orchestrator never issues the transition itself). Skip the transition only if the issue is already "In Progress" or further along (e.g., a `--resume` run) — never regress a status. Confirm the transition landed in the brief reply.
- Instruction: decompose into user-observable acceptance criteria, explicit non-goals, dependencies, and open questions. Apply the Singapore-launch scope filter. Flag anything that warrants CEO sign-off. **Also flag `needs-ui-ux-design: true|false` with a one-line rationale** — true when the issue introduces new user-facing screens/flows, requires meaningful layout or hierarchy decisions, adds to the design system, or asks competitor-aware UX questions; false for pure backend, infra, tooling, refactors with no visible surface, or UI work that just implements an already-specified design.
PM returns a product brief including the `needs-ui-ux-design` flag. Orchestrator relays the brief to the user verbatim (or near-verbatim) and proceeds.

If PM determines the issue is too large for one cycle and proposes splitting → orchestrator stops, surfaces the split proposal to the user, and waits. Do NOT run step 4+ against an unsplit overscope.

### 3. CEO strategic sign-off (spawn `ceo`)

Spawn `ceo` into the team as `ceo` with PM's brief. CEO's job: verdict from the Singapore-launch lens.

Possible verdicts:
- **aligned** → proceed to step 4.
- **aligned-with-conditions** → `SendMessage({to: "pm"})` with CEO's conditions — `pm` already holds its brief in context, folds the conditions into the acceptance criteria, and returns the updated brief. Then proceed to step 4 with it.
- **misaligned-redirect** → orchestrator stops, relays CEO's verdict + proposed strategic alternative to the user, waits. Do NOT proceed to EL without alignment.

`--skip-ceo` bypasses this step. Only acceptable when the issue has no strategic surface (pure tech debt, dependency bump, internal refactor). Document the bypass reason in the Step 3 relay.

**Auto-skip when a CEO verdict is embedded in the issue body.** If the issue body contains a recorded CEO verdict (dated, attributed to `ceo`, with rationale) covering the current scope of work, the orchestrator MAY skip Step 3 without `--skip-ceo`. Treat the embedded verdict as the Step 3 outcome. The Step 3 status MUST cite the verdict's date and one-line summary (`Step 3/11 — CEO sign-off  Agent: skipped (verdict in issue body, YYYY-MM-DD)  Verdict: <one-line>  Next: ...`) so the audit chain remains intact. If the embedded verdict is older than the latest material scope change in the body, do NOT auto-skip — re-spawn `ceo` to re-adjudicate the new scope.

### 4. UI/UX design (conditional — spawn `ui-ux-designer`)

**Gate:** run this step ONLY if PM's step-2 brief flagged `needs-ui-ux-design: true`. Otherwise emit a one-line "Step 4/11 — skipped (no UI/UX design surface)" status and proceed to step 5.

Spawn `ui-ux-designer` into the team as `designer` with:

- The Linear issue id and full issue body.
- PM's product brief (acceptance criteria + non-goals + the `needs-ui-ux-design` rationale).
- CEO's verdict (so the designer knows the strategic frame — solo-travelers-meet-locals, Singapore launch, mobile-first).

Designer's job:

- Research competitor patterns where useful (Meetup, Timeleft, Bumble For Friends, Partiful, etc.).
- Produce a design specification: screen layouts (ASCII or described), user flow, component hierarchy, primary/secondary CTAs, states (loading/empty/error), accessibility notes, design-system alignment.
- Flag any new design-system additions that need CPO consultation.
- NO code. NO Flutter widgets. Specifications and rationale only.

Designer returns a design spec. Orchestrator relays the spec to the user, then proceeds to step 5 with the spec attached.

If the designer flags a new design-system pattern requiring CPO consultation → orchestrator stops, surfaces the open question to the user, waits for direction before proceeding to EL.
### 5. Technical specification (spawn `engineering-lead`)

Spawn `engineering-lead` into the team as `el` with:

- The original issue id.
- PM's product brief (acceptance criteria + non-goals + dependencies).
- CEO's verdict and any conditions.
- The UI/UX design spec from step 4 (if step 4 ran; otherwise note "no design surface").

EL's job:

- Translate product (+ design spec, if any) → technical requirements (NFRs, data model, integration points, technical non-goals).
- Apply the YAGNI test before introducing new abstractions.
- Decompose into a phased technical approach and identify parallelizable sub-tasks.
- Produce one structured brief per SWE sub-task. Each brief MUST include: scope, target files/modules, acceptance-criteria slice, technical non-goals, dependencies on other sub-tasks, suggested scaffolding skills (`/api-new-*`, `/mobile-new-*`). For UI sub-tasks, the brief MUST reference the relevant section of the design spec so SWE implements to the spec, not from improvisation.
- **Briefs MUST be emitted dispatch-ready in EL's final message body** — each as a stand-alone block the orchestrator can paste verbatim into a SWE spawn prompt. Burying the briefs in a result summary ("(b) Five per-SWE briefs A–E, ready for verbatim dispatch") forces the orchestrator to round-trip via SendMessage to extract them, costing a full cycle and a cache miss. If EL only surfaces the briefs as a summary line, treat the brief contract as unmet and re-spawn EL with the explicit ask before proceeding to Step 6.

Orchestrator relays EL's plan + the sub-task briefs to the user, then proceeds.

If EL's feasibility read conflicts materially with PM's scope (e.g., "this is XL, PM committed it to a 1-cycle slice") → orchestrator stops, surfaces both views to the user, waits.

If EL surfaces a technical constraint that breaks the designer's spec (e.g., "this interaction needs an API we don't have time to build") → orchestrator stops, surfaces both views to the user, waits. Resolution may require re-spawning `ui-ux-designer` with the constraint to produce a revised spec.

### 6. Implementation (spawn one `software-engineer` teammate per EL sub-task)

For each sub-task in EL's plan:

- Spawn `software-engineer` into the team as `swe-a`, `swe-b`, … (one stable name per sub-task) with EL's per-task brief as the prompt (verbatim, no editorializing by the orchestrator). **`run_in_background: true`** per the Hard constraints — applies to every first spawn here.
- *(Optional)* For a wide fan-out you MAY mirror EL's sub-tasks onto the shared team task list — `TaskCreate` per sub-task, `owner` set to the matching `swe-*` — so progress and dependencies are visible in one place. This is a convenience, not a requirement; the `SendMessage` re-engagement model below is sufficient on its own.
- **Independent sub-tasks run in parallel** — emit a single message containing multiple Agent tool calls (all backgrounded). Wait for the batch's completion notifications before starting the next round.
- **Dependent sub-tasks run sequentially** — wait for the dependency's background completion notification before spawning the dependent.
- **Gate-landing sub-tasks must precede gate-tripping sub-tasks even when both look independent.** Before fanning out, scan EL's sub-task briefs for cross-cutting concerns: a sub-task that lands a code-style / import / lint / format / type-strictness gate (e.g., ESLint `no-restricted-imports`, a new strict tsconfig flag) and a sibling sub-task whose code shape could trip that gate. Even when neither sub-task names the other as a `Dependencies:` entry, the gate-landing one is implicitly upstream and must commit first. Parallel dispatch on a gate+consumer pair reliably costs one extra fix cycle (TRI-5 sub-tasks B+C did exactly this — B's typed `@aws-sdk/*` mocks landed clean against the un-gated tree, then C's ESLint gate flagged them, requiring a B-fix cycle).
- **Parallel SWEs on the same branch share a working tree — uncommitted files can be swept up by whichever SWE commits first.** When two SWE spawns run in parallel on the same branch, both see each other's in-progress edits in `git status` (Edit/Write writes to disk immediately; only `/github-commit` stages and commits). If SWE-1 finishes first and `/github-commit` stages files in the brief's scope, it may pull in SWE-2's uncommitted overlapping changes (adjacent test files in the same directory, shared helpers, sibling files in the same feature surface). Result: one consolidated commit instead of two split-by-logical-scope commits — the work is correct, but the split discipline is lost. **Mitigations:** (a) prefer file-disjoint parallel batches (different features / directories); (b) when bundling brief siblings that touch adjacent file trees, dispatch sequentially rather than in parallel; (c) accept the consolidated commit as a minor discipline loss when the bundling is semantically coherent (TRI-70 cycle 1: events-namespace + Zod cast + idempotency guard were three logically distinct fixes bundled into `fdccf5f` because both SWEs' working trees overlapped on `apps/api/src/features/users/**`). If (c), note the bundling in the PR description so reviewers see one commit cover multiple intents.

SWE's job per sub-task:

- Implement via the appropriate scaffolding skills.
- Stage commits via `/github-commit`, split by logical scope (feature vs. tooling vs. CLAUDE.md edits) per the orchestrator rule in CLAUDE.md.
- Report: files changed, commits made, any deviation from the brief, any clarifying questions.

**Push behavior — `/github-commit` auto-pushes.** The `/github-commit` skill commits AND pushes by design. The orchestrator MUST NOT instruct SWE to "do NOT push" in the brief — that instruction is contradicted by the skill SWE invokes, creates noise in the SWE's report ("committed and pushed despite instructions"), and surfaces a false security-warning flag from the auto-classifier. The push lands on the feature branch (not main), which is exactly what Step 9 needs anyway. If the orchestrator has a legitimate reason to keep a commit unpushed (rare — e.g., needing to amend before any push), use a different commit path; don't fight `/github-commit`.

If a SWE teammate asks a clarifying question:

- Product-side question → `SendMessage({to: "pm"})` with the specific question (PM answers from its live context).
- Technical-side question → `SendMessage({to: "el"})`.
- `SendMessage` the answer back to that `swe-*` — it keeps its in-progress working state, so it resumes mid-task rather than restarting.

### 7. Architecture review (spawn `architecture-reviewer` as `reviewer`)

Once SWE reports complete on all sub-tasks, engage `reviewer`. The reviewer runs:

- `/api-review-architecture` if `apps/api/**` changed.
- `/mobile-review-architecture` if `apps/mobile/**` changed.
- Both if cross-stack.

Reviewer returns a violations report (file:line, severity, rule). Reviewer NEVER edits code. Its review skills always scope to the live WIP diff, so re-engaging the same `reviewer` teammate via `SendMessage` each cycle (rather than a fresh spawn) carries no staleness risk — it re-scans the current tree.

Orchestrator relays the report to EL via `SendMessage({to: "el"})` (EL retains the technical plan — send only the findings). EL's response per violation:

- **fix-now** → `SendMessage` the relevant `swe-*` to fix in the current branch.
- **fix-followup-issue** → EL drafts a follow-up note; orchestrator `SendMessage`s it to `pm` now and queues the step-10 filing.
- **accept-with-rationale** → EL writes a one-line rationale; orchestrator captures it for the PR description.

Loop steps 6–7 until reviewer is clean (no `error`-severity findings) OR EL has signed off on remaining items.

### 8. QA (spawn `qa` as `qa`)

Engage `qa` to run the project's test scripts on the touched surfaces (re-engage via `SendMessage` each cycle — qa always runs against the live tree, so no staleness):

- Backend changes → `format:check`, `typecheck`, `lint`, `test` on `@tribely/api`.
- Mobile changes → `mobile:format:check`, `mobile:analyze`, `mobile:test`.

QA returns pass/fail per script with failure excerpts. QA NEVER edits code.

**Sequential gate behavior.** qa scripts run sequentially per stack (format:check → typecheck → lint → test; for mobile: format:check → analyze → test). Downstream failures are MASKED until upstream gates pass — a typecheck failure prevents the test step from running at all, so unrelated test failures may surface only on a later cycle. Do NOT conclude "everything else is clean" from a single failure report. Expect multiple qa cycles when fixes cascade across gate layers, and budget the loop accordingly. This is normal, not a workflow flaw.

Orchestrator relays failures to EL via `SendMessage({to: "el"})`. EL re-briefs the relevant `swe-*` (also via `SendMessage`) on each failure. Loop steps 6–8 until QA passes clean.

The orchestrator does NOT run test scripts between SWE fix cycles to "double-check" before re-spawning qa — see the Hard constraints above.

**Escalation:** if the same QA failure persists across 3 SWE fix cycles, qa flags `escalate=true`. Orchestrator surfaces to the user with EL's options (refactor, accept-with-rationale, split to follow-up). Do NOT silently keep retrying.

### 8.5. Manual on-device smoke (conditional)

**Gate.** Run this step ONLY if EITHER condition is met. Otherwise emit `Step 8.5/11 — Manual on-device smoke  Agent: skipped  Verdict: no hero-flow / time-validator surface  Next: PR creation` and proceed to step 9.

1. **Hero-flow path signals.** Run `git diff --name-only main...HEAD` and match changed files against:
   - **(a) create-and-publish event:** `apps/mobile/lib/src/features/events/presentation/**/create_event*` OR `apps/mobile/lib/src/features/events/**/usecases/publish_event*` OR `apps/mobile/lib/src/features/events/**/usecases/create_event*` OR `apps/mobile/lib/src/features/events/presentation/widgets/step_navigation_bar*` — the last is the create-event flow's shared bottom-nav widget that composes the multi-step form; its filename doesn't carry the `create_event*` prefix, so a strict glob-match would skip smoke on a genuine hero-flow surface. Layout-only changes here (button show/hide, anchoring) aren't covered by goldens on Linux CI, so manual smoke is the verification path. Precedent: TRI-93 (hide the dead Step-1 Back button).
   - **(b) sign-up / sign-in / email verification:** `apps/mobile/lib/src/features/auth/**` OR `apps/api/src/features/auth/presentation/**`
   - **(c) browse + request to join:** `apps/mobile/lib/src/features/events/presentation/**/browse*` OR `apps/mobile/lib/src/features/events/presentation/**/event_detail*` OR `apps/mobile/lib/src/features/join_requests/**/presentation/**`
   - **(d) selfie verification capture:** `apps/mobile/lib/src/features/users/presentation/pages/selfie_consent*` OR `apps/mobile/lib/src/features/users/presentation/pages/selfie_capture*` OR `apps/mobile/lib/src/features/users/presentation/controllers/selfie_capture_controller*` — consent → camera + ML-Kit face detection → direct upload; device-dependent (camera hardware, ML-Kit, OS permissions, upload) and unexercised by widget tests. Precedent: TRI-23.

   *Extend this list when a new hero flow lands; do not infer.* Payments are deferred for the Singapore launch — do NOT add a pay flow.

2. **Time-dependent validator grep signals.** Run `git diff main...HEAD -- 'apps/mobile/**/*.dart'` and scan for any of: `DateTime.now()`, `Duration(minutes:`, `Duration(seconds:`, `Duration(hours:`, `.isAfter(`, `.isBefore(`, `DateTime.now().add(`, `DateTime.now().subtract(`. Also flag identifier substrings: `expires`, `expiry`, `buffer`, `window`, `cooldown`, `startsAt`, `endsAt`. Pragmatic — false positives cost one extra checklist item; false negatives are the real cost.

3. **Skip conditions (no smoke needed).** Changed-files set is a subset of any of:
   - `apps/api/**` only (backend-only — no mobile surface to smoke)
   - `.claude/**` only (orchestration meta-tooling)
   - Docs-only (`*.md` / no `.dart` / `.ts` / `.tsx` files touched)
   - `.github/**` only (CI-only)

**Checklist generation.** When the gate matches, the orchestrator produces a manual smoke checklist with the following properties:

- For each matched hero flow: a named click-by-click sequence that exercises the *specific* added/changed surface in the diff — not generic "tap around." Each step names the screen, the widget interacted with, and the expected post-condition.
- For each matched time-dependent validator: one item naming (i) the validator (e.g., `startsAt >= now + 5min`), (ii) the wait duration that crosses its threshold (e.g., "wait 6 minutes for a 5-minute buffer"), (iii) the expected behavior flip (verdict, hint visibility, submit enabled-state).
- **Reproducibility contract:** the checklist must read top-to-bottom on a clean install by someone who didn't write the PR and yield the same pass/fail verdict. Generic "tap around" fails this bar; named steps pass it.

**Delivery — two destinations.**

1. **Primary:** orchestrator posts the checklist inline to the user in chat and waits for explicit "passed" / "failed" sign-off. **No auto-Done — the user signs off after the smoke pass.**
2. **Secondary:** the same checklist is pasted into the PR description (step 9) under a `## Manual smoke checklist` heading for audit.

**Failure path.** User reports a fail → orchestrator re-routes the symptom to EL (same loop shape as steps 7–8). Re-smoke after fix.

**Status emission.** `Step 8.5/11 — Manual on-device smoke  Agent: orchestrator + user  Verdict: <passed|failed|skipped>  Next: PR creation`.

### 9. PR creation (orchestrator invokes `/github-pr`)

Once reviewer and qa are both clean:

1. Verify working tree is clean (`git status`), commits are pushed, branch is up to date with `main` (rebase if needed — delegate to `software-engineer` if rebase produces conflicts).
2. Invoke the `/github-pr` skill. The skill auto-detects the Linear issue from the branch name.
3. In the PR description, include EL's accept-with-rationale notes from step 7 (if any).
4. **Document any deviation from a prescriptive ticket body in the PR description, NOT by editing the ticket body.** When the ticket prescribes a specific file shape / API / pattern that EL overrides during step 5 (e.g., the ticket says "wrap in `FormField<T>`" and EL rules it dead code because no parent `Form` exists), capture the deviation verbatim in the PR body under a "Notable engineering decisions" heading: state what the ticket said, what was implemented, and EL's rationale. The ticket body stays as-authored so the audit trail is preserved — future readers see both the original instruction and why it was overridden. PM does NOT retroactively edit the issue description to "match reality."
5. Output the PR URL to the user.

### 10. Linear update (re-engage `pm` via `SendMessage`)

Final `pm` re-engagement — `pm` already holds the original brief, CEO conditions, and every ruling relayed during the run (per the Hard constraints), so this message confirms the close-out actions rather than re-establishing scope:

- **Target status:** Call `mcp__plugin_linear_linear__get_issue` before issuing any state change. The issue should be arriving from "In Progress" (set by PM at Step 2 intake). If the PR is still open, move the issue to "In Review". If the PR has already been merged (e.g., Linear's GitHub integration auto-completed the issue, or the user merged before step 10 ran), confirm the status is "Done" and skip the transition — do NOT regress from "Done" to "In Review". Lifecycle summary: Step 2 → "In Progress", Step 10 → "In Review", merge → "Done" (human/integration, never the workflow).
- Comment the PR URL on the issue.
- File any follow-up issues EL queued in step 7 (`fix-followup-issue` items). **Non-engineering follow-ups are NOT ticketed** — work with no repo/code deliverable (operational procedures, external-counsel engagement, business ops) routes to its owning agent (`ceo`) or the user, and is listed in PM's closeout as "non-ticketed actions" instead. The Linear backlog is the engineering queue; the Step 1 engineering-ticket guard would refuse these at intake anyway. Carve-out: manual human configuration steps (owner mints a credential, sets an env var on the deploy host — agents-draft / human-executes) ARE engineering work and ARE ticketed; any env var involved must be reflected in `.env.example` with the standard annotations (blank-allowed?, sample/format, prod-recommended, default-if-any).
- **Triage any open questions EL surfaced.** Default: PM decides — file as a separate Linear ticket, bundle into an existing ticket, or, only if the question is genuinely outside any agent's domain (taste, owner-only authority), surface to the user. Do NOT pre-instruct PM to "surface to user" in the Step 10 prompt — that's an orchestrator-induced bounce. The repo owner hired the agents to handle their domains; ticket-scoping / sequencing / dependency-mapping is squarely PM's. See memory `feedback_dont_bounce_agent_domain_decisions` for the underlying rule.
- **Do NOT edit the issue description / acceptance criteria retroactively to match the implementation.** Implementation deviations from a prescriptive ticket body are captured in the PR description (step 9, item 4), not by rewriting the ticket. The original ticket body is the audit trail; the PR description is the "what we actually did and why" trail. Both stay intact.

Orchestrator emits the Step 10 summary and proceeds to Step 11.

### 11. Learning cycle + team teardown (orchestrator)

The cycle isn't finished when the PR is open — it's finished when the workflow's learnings are captured and the team is cleaned up.

1. **Learning pass.** Invoke `/learn` (the orchestrator-only reflection skill). It scans this session for moments where the user corrected, clarified, or affirmed how the agents or workflow should operate, and migrates each into its right durable home — agent-ability learnings → `.claude/agents/<agent>.md`, workflow learnings → the relevant `SKILL.md`, project-specific facts → memory. Pass a focus if one theme dominated the cycle (e.g. `/learn routing-corrections`). `/learn` is read-only until you confirm each proposed write — review its diffs, don't rubber-stamp. If the cycle ran clean with no corrections, `/learn` finds nothing to codify; that's a valid outcome, not a failure. This is what compounds the workflow: each delivered issue leaves the agents and skills a little sharper than it found them.
2. **Tear down the team.** After `/learn` completes: shut down each teammate via `SendMessage({to: "<name>", message: {type: "shutdown_request"}})`, wait for them to terminate, then call `TeamDelete`. (`TeamDelete` fails while members are still active, so shut down first.) The same teardown applies to a reused team on a `--resume` run, at the true end of the workflow.
3. Emit the final `Step 11/11` status and stop.

## Outputs at each step

After each step, the orchestrator emits a structured status update to the user:

```
Step <N>/11 — <step name>
  Agent: <teammate-name or "orchestrator" or "skipped">
  Verdict: <one-line verdict>
  Next: <one-line next-step preview, or "blocked: <reason>">
```

Step 4 (UI/UX design) is conditional — when skipped, emit `Step 4/11 — UI/UX design  Agent: skipped  Verdict: no UI/UX design surface  Next: EL technical spec`. Step 8.5 (Manual on-device smoke) is conditional — when skipped, emit `Step 8.5/11 — Manual on-device smoke  Agent: skipped  Verdict: no hero-flow / time-validator surface  Next: PR creation`. Step 11 (Learning cycle + team teardown) always runs.

Keep updates terse. The user reads these to track a long workflow without reading every agent transcript.

## Failure modes and recovery

| Failure | Action |
|---|---|
| Issue not in Tribely team | Refuse. Ask user to verify the id. |
| Issue is a non-engineering ticket (no repo/code deliverable, no technical surface) | Refuse at step 1 BEFORE creating branch or team. Route to its owner: strategic → `ceo`; backlog/product shaping → `product-manager`; regulatory/policy → surface to user. |
| `main` is dirty at step 1 | Refuse. Ask user to stash/commit before starting. |
| Branch already exists | Ask user: reuse via `--resume`, or pick a different slug. |
| PM proposes split (issue too large) | Stop. Relay split to user. Do not proceed. |
| CEO misaligned-redirect | Stop. Relay verdict + alternative. Wait for direction. |
| Designer flags new design-system pattern needing CPO consultation | Stop. Surface to user. Wait for direction before EL. |
| EL technical constraint breaks designer spec | Stop. Relay both views. May re-spawn `ui-ux-designer` with the constraint. |
| PM↔EL feasibility/scope conflict | Stop. Relay both views. Do not pick a side. |
| SWE clarifying question | Pause SWE. Route to PM (product-side) or EL (technical-side). Resume with the answer. |
| Reviewer/QA loops 3× without progress | Escalate to EL. Surface EL's options to user. |
| Smoke checklist fails on the user's device | Re-route the symptom to EL (steps 7–8 loop shape). Do NOT proceed to step 9 until the user signs off "passed" on a re-smoke. |
| Rebase conflict before PR | Delegate to `software-engineer` to resolve. If non-trivial, surface to user. |
| PATH-missing CLI (`gh`, `flutter`, `npm`) | Report to user. Do not hunt absolute paths in `/opt/homebrew/bin/`, `/usr/local/bin/`, etc. |
| Classifier-blocked CLI (`prisma migrate dev`, `prisma migrate reset`, `prisma db execute`, etc.) | Surface to user with options: (a) add a Bash permission rule in `settings.json` (`Bash(npx prisma migrate dev:*)` etc.), (b) run the command from terminal. Do NOT loop on retries — the auto-classifier cannot see `AskUserQuestion` responses, so user approval via that path does NOT unblock the next attempt. The classifier needs a settings.json rule OR the user running the command outside the orchestrator. |
| Linear workspace at free-tier issue cap (`save_issue` returns `Usage limit exceeded - You've exceeded the free issue limit`) | Distinct failure mode from the auto-classifier — this is a **Linear workspace-level cap**, not a tool-permission issue. PM has no retry path: the workspace can't accept new issues until upgraded. PM falls back to **emitting the full drafted ticket payload (title + team + project + labels + priority + body) verbatim in its closeout summary** so the orchestrator can relay it to the user for manual filing (or the user upgrades the workspace and re-files). Do NOT silently skip the follow-ups. Do NOT bundle multiple drafts into one ticket as a workaround. Most-urgent draft (legally-urgent / launch-blocking) is called out first. Same handling applies if the cap is hit at Step 3.5 (PM folding CEO conditions) or any other PM-write moment, not just Step 10. |
| Cross-branch dev-DB drift blocks `prisma migrate dev` | When the shared dev DB has migrations applied from another in-flight branch (experimental work the upstream branch never committed) and `prisma migrate dev` refuses to proceed due to drift, **bypass via hand-authored migration SQL matching the existing migration directory's pattern** (or `prisma migrate diff --from-migrations ... --to-schema-datamodel ... --script` if `shadowDatabaseUrl` is configured). The new migration is generated purely from committed state — the live dev DB is never touched. The upstream branch owner resolves the drift separately. Do NOT (a) try to reset the shared dev DB without explicit user authorization, (b) reconstruct invented SQL for the upstream branch's migration to satisfy the drift check (this contaminates the PR with the wrong content), or (c) wait for the upstream branch to land before proceeding (the drift is environmental, not architectural — the two PRs are independent). TRI-79 is the precedent. |
| `/github-pr` fails (auth, network) | Surface to user with the gh error. Do not retry blindly. |
| Teammate context lost mid-run (session/process ended) | Teammates and their accumulated context are gone. On `--resume`, recreate the team and re-spawn only the teammates the remaining steps need, rebuilding context from the issue body + branch diff (per Step 1 `--resume`). Do NOT assume a re-spawned teammate remembers prior cycles. |
| `TeamDelete` fails ("active members") at Step 11 | A teammate is still active. `SendMessage` each remaining teammate `{type: "shutdown_request"}`, wait for termination, then retry `TeamDelete`. |
| `TeamCreate` fails at Step 1 — "Already leading team `<prior-team>`" | A prior cycle's team was never torn down (its session ended before Step 11). Read `~/.claude/teams/<prior-team>/config.json` to confirm it's a stale prior-cycle team (NOT the current issue's). Then `SendMessage` `{type: "shutdown_request"}` to each listed member; the sub-agents terminate (the config's `members` array drops to just `team-lead`), then `TeamDelete` succeeds and you can `TeamCreate` the new team. Distinct from the Step-11 `TeamDelete` row above, which assumes the same live session — here the blocking team belongs to an already-ended session. |

## Edge cases

- **Pure spike / research issue.** Use a `chore/` branch. Skip steps 4 (design), 6–8 (no implementation, no review, no qa). PM closes the issue in step 10 with the findings.
- **Cross-cutting refactor with no Linear issue.** This skill requires an issue id. Route to PM via `/linear-techdebt` to file one first, then re-invoke `/work-on-issue` with the new id.
- **Hotfix on production.** The full 11-step workflow is overkill. Use a streamlined path: PM frames briefly → EL gives the fix shape → SWE implements → qa runs → PR. Skip steps 3 (CEO), 4 (design), and 7 (reviewer) if the fix is mechanical and reviewer-clean by construction. Document the skipped steps in the PR description.
- **Design-only issue (spec, no implementation).** Two sub-cases — pick by where the deliverable lives:
  - **(a) Linear-attached deliverable.** Designer's spec lands as a Linear comment, attachment, or document — nothing in the repo. Run steps 1–4, then PM closes the issue in step 10 with the design spec attached. Skip steps 5–9 entirely (no EL spec, no SWE, no review, no qa, no smoke, no PR).
  - **(b) Repo-committed markdown deliverable.** Designer's spec lands as a markdown file in the repo (e.g., `docs/design/<slug>.md`) so it's greppable by future SWE / reviewer agents. Run steps 1–4, then route directly to `software-engineer` to commit the spec verbatim (1 commit, `docs(design):` prefix, no code). Skip steps 5 (EL — no technical brief needed), 7 (reviewer — no architecture surface), 8 (qa — no test surface), and 8.5 (smoke — no UI to exercise) per the pure-documentation exception in Hard constraints. Run step 9 (PR via `/github-pr`) and step 10 (PM Linear update + file follow-up implementation tickets) normally. The PM follow-up tickets MUST reference the committed spec path so future SWE work can read it cold.
- **Multiple issues in one branch.** Discouraged — splits review scope. If the user insists, run steps 2–5 separately per issue and merge the EL plans before step 6. The branch name uses the lead issue id; the PR body references all of them.
- **Re-engaging a teammate within a step.** The default and expected pattern (e.g., `SendMessage`ing `el` the reviewer report). Within the live session the teammate retains its full context, so a re-engagement sends only the delta, never a re-stated brief. A *fresh* `Agent` spawn (new teammate, blank context) is reserved for genuinely new work — a new SWE sub-task, or rebuilding a teammate whose context was lost when a prior session ended (see `--resume`).
- **File-move refactors can surface pre-existing drift in reviewer scope.** When a refactor moves `.ts` files between reviewer-excluded paths (e.g., test files inside `__test__/` subdirectories, which `/api-review-architecture` skips by scope) and reviewer-included paths (the parent directory, where fake/contract files become in-scope), the next reviewer run can flag structural drift that pre-existed the refactor — A11 cross-feature imports, A17 lateral duplicates, etc. that were hidden by the exclusion. **These are NOT regressions introduced by the PR.** Adjudicate via EL as fix-followup-issue (precise next-touch trigger) or accept-with-rationale, not as fix-now items that must land in the same PR. Polishing every pre-existing smell exposed by a file move risks an indefinite scope-creep loop on what was supposed to be a bounded refactor. TRI-77 is the precedent — the `__test__/` → co-located migration surfaced 3 findings that EL deferred / accepted because they were pre-existing.
- **Agents-draft / human-executes tickets (cloud provisioning, infra bringup).** When the ticket follows the CLAUDE.md cloud-provisioning convention — agents author the runbook + code stubs; the repo owner executes provisioning against real cloud accounts out-of-band — the orchestrator MUST: (a) include the full human-execute checklist verbatim in the PR description so it survives merge as the authoritative reference; (b) when the user signals they're ready to execute (post-merge), surface a CONDENSED inline checklist with the exact commands + expected outputs per step, not just a pointer to the runbook file; (c) pause for explicit user confirmation at each human-execute step before suggesting the next — do NOT batch-list all steps and silently mark the workflow done. The pause-protocol exists because real cloud-account work is destructive on failure and the user is the only actor with credentials. **Precedents:** TRI-77 (selfie storage), TRI-2 (production deployment / image bringup). When a new ticket matches this convention, scan the matching ticket bodies before generating the checklist — they establish the format owner expects.

## What this skill is NOT

- **Not an agent.** It's a procedural script the orchestrator follows.
- **Not a substitute for thinking.** The orchestrator still applies judgment at each step's verdict — relaying briefs, asking the user when blocked, choosing parallel vs. sequential SWE spawns from EL's plan.
- **Not a one-shot.** Steps 6–8 loop (SWE ↔ reviewer ↔ qa). The orchestrator must hold state across the loop (what failures are open, what fixes are pending) and surface concise progress to the user.

## Important

This skill orchestrates the multi-agent workflow defined in `CLAUDE.md` → "Agent orchestration & role boundaries". If those role boundaries change, update this skill in lockstep. The skill is the choreography; CLAUDE.md is the why.

The Agent-Team coordination model assumes the orchestrator drives all `SendMessage` re-engagement and that agents still reply self-contained to the orchestrator (which their agent files already require). It does NOT depend on agents initiating peer-to-peer sends — so it works as written even where an agent file still says direct messaging is unavailable. If a future change moves to genuine peer-to-peer agent messaging (e.g. reviewer→EL direct), reconcile the agent definitions in `.claude/agents/` that currently instruct inline-only emission before relying on it.
