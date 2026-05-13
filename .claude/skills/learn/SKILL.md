---
name: learn
description: ORCHESTRATOR-ONLY. Reflect on the current conversation; distill agent-ability + workflow learnings; migrate them to agent definitions or skill prompts; clean up memory entries that have been moved. Strict domain boundary — skills/agents stay project-agnostic (ability + workflow only); memory keeps project-specific context.
---

# /learn

```
/learn               # reflect on the full conversation
/learn <focus>       # narrow to a topic (e.g. /learn routing-corrections)
```

**Caller scope:** orchestrator (main loop) ONLY. Sub-agents must NOT invoke this skill — they don't have the cross-agent context to reflect on workflow. If a sub-agent tries to call it, refuse and route the request back to the orchestrator.

## What this skill is

A reflection pass at the end (or mid-point) of a working session. The orchestrator scans the conversation for moments where the user **corrected**, **clarified**, or **affirmed** how the agents or workflow should operate — and codifies those learnings into the right home:

- **Agent-ability learnings** → `.claude/agents/<agent>.md` (how a specific agent operates)
- **Workflow learnings** → `.claude/skills/<skill>/SKILL.md` (how agents coordinate)
- **Project context** → memory (Tribely / Singapore / ticket-specific facts)

It also **migrates** memory entries that turn out to be agent-ability or workflow rules — moving them to the right home and removing the memory entry — so the layers stay clean.

## Hard constraints (read first)

These are **non-negotiable**:

- **Skills and agents are project-agnostic.** Never put `Tribely`, `Singapore`, `TRI-XX`, "the Singapore launch", or any project-specific noun into a skill or agent definition. Skills/agents describe ABILITY (what an agent can do, how it operates) and WORKFLOW (how agents coordinate). They must be portable: the same skill or agent definition should make sense if the user clones it to a different project tomorrow.
- **Memory is project-specific.** Anything Tribely / Singapore / TRI-XX / "this codebase uses X library" / "TRI-27 was Y" stays in memory. If the orchestrator already moved a project-agnostic rule out of memory into a skill, **remove the memory entry** and update `MEMORY.md` to drop the index line — otherwise the memory rots into duplication.
- **Don't invent learnings.** Only codify rules the user actually stated, confirmed, or repeatedly demonstrated a preference for. If a behavior is your own inference and the user never engaged with it, leave it alone — it's not load-bearing yet.
- **Don't delete agent/skill content silently.** If you're replacing a rule, leave a one-line marker about the move in the commit message or skill changelog. If you're tightening a rule, show the diff in the relay.
- **Preserve `why`.** When codifying a rule, include the rationale (often a specific incident the user named). Future readers need to judge edge cases, which requires understanding why the rule exists.

## Procedure

### 1. Scan the conversation

Read the running session. Look specifically for these signals:

| Signal | What it means | Where it lands |
|---|---|---|
| User correction: "stop X" / "no, do Y" / "@agent should never..." | Agent-ability rule | `.claude/agents/<agent>.md` |
| Workflow correction: "after X you must always Y" / "this routing was wrong, it should go EL→PM, not PM→EL" | Workflow rule | `.claude/skills/<skill>/SKILL.md` |
| Repeated user explanation of system behavior | Either ability or workflow — match by who/what | Agent or skill |
| User affirmation of a non-obvious choice ("yes that's the right call") | Confirms current behavior is correct | No edit; optionally surface as confirming feedback memory |
| Project-specific fact ("we ship in Singapore", "TRI-XX is the discover ticket") | Project context | Memory |
| Existing memory entry that's actually a workflow rule | Migrate target | Move to skill; remove from memory |
| Existing memory entry that's project-specific and current | Keep in memory | No action |
| Existing memory entry that contradicts current behavior or names a removed file | Stale | Remove from memory |

If `<focus>` was passed, narrow the scan to that topic. Otherwise scan the whole conversation.

### 2. Classify each candidate learning

For each learning candidate, decide:

1. **Is it project-agnostic?** Would the same rule apply on another codebase? If yes → skill/agent. If no → memory.
2. **Is it about a specific agent's behavior, or about how agents coordinate?** Specific agent → agent definition. Coordination → skill.
3. **Does it already live somewhere?** Search agents, skills, and memory before adding. If already codified, no action. If codified but stale, update in place.

### 3. Apply updates

**For agent edits** (`.claude/agents/<agent>.md`):

- Add the new rule under a relevant existing section (or create one if needed).
- Include the rationale — one short line ("Why: user corrected this in [context]").
- Use the same tone and structure as existing bullets in that file.

**For skill edits** (`.claude/skills/<skill>/SKILL.md`):

- Add under `Hard constraints` if it's non-negotiable workflow behavior.
- Add inline in the relevant step's instructions if it's procedural.
- Match the existing skill's voice.

**For memory edits** (`.claude/projects/<project-slug>/memory/`):

- New memory file: `<type>_<short_slug>.md` (e.g., `project_<context>.md`, `feedback_<topic>.md`). Use the existing memory frontmatter format.
- Update `MEMORY.md` index — one line per memory file, under ~150 chars.
- Remove migrated entries: delete the memory file AND its line in `MEMORY.md`.

### 4. Apply the domain boundary check

Before saving anything to a skill or agent: grep the proposed edit for project-specific tokens. Reject the edit if it contains:

- `Tribely`, `Singapore`, `TRI-`, `gotribely`, `linear.app/loonas/`
- Specific framework / library names that aren't truly universal (e.g., `flutter_map ^8.3.0` is too specific; "the map library" is fine in a workflow context).
- File paths that include `apps/mobile/`, `apps/api/`, or any project-relative path.
- Names of specific people, internal team channels, or specific past commits / PRs.

If the rule needs project-specific examples to make sense, that's a strong signal it should live in memory or in `CLAUDE.md`, NOT in a skill or agent definition.

### 5. Commit and relay

- Commit each edit category as a separate commit per the repo's commit-split convention (one commit for agent edits, one for skill edits, one for memory cleanup).
- In the commit message body, name the source signal: "User correction in [date / topic context]: <quote or paraphrase>".
- Report back to the user: list of agent/skill/memory edits with one-line rationale each. Surface anything you considered but rejected (with the rejection reason — e.g., "Considered codifying X; rejected because it's project-specific").

## What this skill is NOT

- **Not auto-applied.** It runs on user invocation only. The session is not retroactively re-shaped by it.
- **Not a substitute for the user explicitly saying "remember this".** The user can still ask the orchestrator to save a memory directly mid-conversation.
- **Not an opportunity to refactor the agent/skill registry.** Apply learnings narrowly. Don't restructure files, don't rename agents, don't introduce new abstractions. If a learning suggests a bigger refactor, surface it as an open question, don't take action.
- **Not a place to add inferred best-practices.** Only codify rules the user actually stated or affirmed.

## Edge cases

- **The conversation hasn't surfaced any clear corrections.** Report "no actionable learnings" and exit. Don't manufacture rules.
- **A user statement is ambiguous about which agent it targets.** Ask the user to clarify (the rare case where this skill stops and surfaces a question).
- **The proposed edit would duplicate an existing rule.** Skip it; mention in the report.
- **The user asked to remember something during the session.** That was already saved at the time — verify it's there; no re-save.
- **A workflow rule was already partially added to a skill but the rationale or "how to apply" is thin.** Sharpen it. Don't leave half-codified rules.
- **A memory entry references a file that's been deleted.** Remove the memory entry.
- **The user invoked `/learn` immediately after a corrective message.** Treat that correction as the primary signal; still scan the rest of the conversation for related signals.

## Domain reminder

This skill's job is to keep the three layers — **agents**, **skills**, **memory** — clean and properly scoped. Agents and skills travel with the orchestration system across projects. Memory is the per-project annotation layer. If a rule could be packaged and shipped to another team's repo, it belongs in agents/skills. If it only makes sense given this project's specifics, it belongs in memory.

## Important

This skill is meta-tooling. It edits `.claude/**` directly (orchestrator-direct, per the orchestrator-no-edits exception for `.claude/` content). It does NOT edit project source code, never writes to Linear, and never opens PRs autonomously — it stages commits on whatever branch is current; the orchestrator routes through `/github-commit` and optionally `/github-pr` afterward.
