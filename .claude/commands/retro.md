---
description: Run a post-run retrospective on a long multi-agent run, harvest durable learnings, and turn the systemic ones into reviewed refinements to the agents/commands/templates/memory — human-gated, uncommitted.
argument-hint: [run-descriptor | work-item-id | transcript-path]
---

Run a retrospective on the multi-agent run identified by **$ARGUMENTS** (default: the run that just completed in **this session**). Harvest what was learned, separate durable/systemic signal from one-off noise, and turn the systemic findings into concrete, reviewed edits to the pipeline's own `.claude/` definitions — so the next run doesn't hit the same wall.

You are the orchestrator and you run this in the **main loop** (so you can fan out the `retro-analyst` agent — subagents can't spawn subagents). You apply edits yourself; `retro-analyst` only verifies and proposes. Keep the user in the loop at **two human gates**: pick-the-findings, then approve-the-edits.

## Hard rules (non-negotiable)

- **Durable + systemic only.** A finding earns a change only if a *future* run would hit it again. Run-specific facts (this PBI's fields, a one-time typo) are noise — record them as "one-off" and change nothing. Be ruthless: most observations are not refinements.
- **Evidence or it didn't happen.** Every proposed change cites a concrete artifact from the run — a quoted reviewer blocker, a plan↔implementation deviation, an agent that reported it couldn't do something, a doc-vs-code mismatch. No evidence → drop it.
- **Verify against the live file before proposing.** A proposed edit to `agents/X.md:NN` is only valid if that file *still says* what the finding claims. The `retro-analyst` re-reads the current target and confirms the anchor; never propose a diff against remembered text.
- **Dedup against memory.** If a learning is already encoded in the target agent's `agent-memory/<agent>/MEMORY.md` (or its prompt), don't re-propose it. Surface it as "already covered."
- **Never change behavior silently, never commit.** All edits are made **uncommitted** for human review (the user commits). Preserve each agent's guardrails; a refinement tightens or corrects — it never loosens a guardrail. If a candidate finding would weaken a guardrail, drop it from the report and flag it to the user as out of scope.
- **Preserve what worked.** The report names the run's *strengths* too, so a later edit doesn't regress a pattern that's pulling its weight.

## Steps

### 1. Scope the run
Identify what is being retro'd. From `$ARGUMENTS` or the session: which command ran (`/implement-pbi`, `/decompose`, `/replicate-legacy`, …), the work-item id(s), and the artifacts it produced. Locate them on disk (the research digest + plan in `.claude/plans/pbi-<id>-*.md`, the feature branch, ADO comments). If `$ARGUMENTS` is a transcript path for a *past* run, read it; otherwise the live session context is your primary source. Show the user a one-paragraph scope summary and the artifact list.

### 2. Harvest signal (you, from the run)
Sweep the run for learnings. Look specifically for:
- **Evaluator findings & their root cause** — every reviewer `blocker`/`issue` (planner, plan-reviewer): what was wrong, and *why the optimizer drafted it that way* (that "why" is usually the systemic fix).
- **Plan ↔ implementation deviations** — anywhere the implementer/UI-builder had to diverge from the approved plan (renames, shape mismatches, "the analog actually does X"). A deviation is a signal the plan/agent guidance was off.
- **Agent-coordination failures** — an agent that reported it *couldn't* do something the orchestration assumed it could (e.g. "couldn't invoke the reviewer"), or a fallback the orchestrator had to drive by hand.
- **Repeated human/orchestrator interventions** — anything the human had to correct, or the orchestrator had to do manually, that a better agent/command prompt would have handled.
- **Doc-vs-code mismatches** — a template/agent prompt that states a convention the live codebase contradicts (these are the highest-value fixes — they propagate to every future run).
- **Unresolved open questions** — what the planner/reviewer left for a human, and whether the *agents* could have resolved it from the code.
- **What worked** — patterns to preserve (so a later edit doesn't regress them).

Draft each as a candidate finding: `evidence (quote/cite) → observed problem → suspected target artifact → suspected systemic vs one-off`.

### 3. Classify & verify (fan out `retro-analyst`, orchestrator-owned)
For the candidate findings that touch a `.claude/` file, hand them to **`retro-analyst`** (read-only) to verify against the *current* target files. Batch the candidates and issue them as `Task` calls — split into parallel calls by target area when there are many (e.g. one for `agents/*`, one for `templates/* + commands/*`) so they run concurrently. Pass each candidate's evidence + suspected target inline.

`retro-analyst` returns, per finding, a verdict: **`confirmed`** (anchor still present → exact suggested edit), **`stale`** (already fixed/encoded in prompt or memory → drop), **`misattributed`** (wrong target → the correct one), or **`one-off`** (not systemic → record only). It classifies and proposes; it does **not** edit.

Resilience fallback: if you cannot invoke `retro-analyst` — either the nested-subagent limitation, **or because `retro-analyst` was authored earlier in *this* session and the harness only loads agents at startup** (so the very first `/retro` run right after creating it can't spawn it yet) — do the verification yourself: Read each target file, confirm the anchor still says what the finding claims, verify any doc-vs-code claim against the live code, and draft the edit.

Assemble the verified findings into a **Retro Report**, grouped by target file, each with: priority (P1 propagating defect / P2 coverage gap / P3 polish), the evidence quote, root cause, the target file + **proposed diff**, and the systemic/one-off tag. Put preserved-strengths in their own section.

### 4. Gate 1 — pick the findings
Show the user the full Retro Report. **Ask which findings to action** (default-recommend the P1s). Let them edit, drop, or reclassify. Resolve any ambiguity about *intent* here — a refinement that changes how an agent behaves is the user's call, not yours.

### 5. Gate 2 — approve the edits
For the selected findings, present the **exact edits** you will make (file + before/after). **Explicitly ask permission to apply.** Wait for yes. (You're editing the pipeline's own definitions — don't start without approval.)

### 6. Apply (uncommitted)
On approval:
- **Edit the target `.claude/` files** (`agents/*.md`, `commands/*.md`, `templates/*.md`) with the approved changes. Make the minimal precise edit; match the file's existing voice and structure.
- **Write durable facts to memory** — a learning that's a *fact* (a verified convention, a gotcha) rather than a prompt change goes to the relevant agent's `agent-memory/<agent>/` (its own dir, with a `MEMORY.md` index line), per the memory convention. One fact per file.
- **Update `.claude/ORCHESTRATION.md`** if a command/agent's described behavior changed (keep the map true to the territory).
- **Log tool-candidates** if the retro revealed a repeated inline-helper pattern (`.claude/agents/tool-candidates.jsonl`).
- **Write the retro artifact** to `.claude/retros/retro-<YYYY-MM-DD>-<slug>.md` (tracked): the scope, the actioned findings with their diffs, the deferred/one-off findings (so the next retro doesn't re-litigate them), and the preserved strengths.
- **Do NOT commit, push, or open a PR.** Leave everything uncommitted.

### 7. Report
Summarize: which files changed and why (one line each), what went to memory, what was deferred as one-off, and the path to the retro artifact. Remind the user the changes are **uncommitted** in `.claude/` (and the retro doc) awaiting their review — they commit when satisfied. Note that prompt/template edits take effect on the *next* run.

## Notes
- **Two human gates only:** pick-the-findings (step 4) and approve-the-edits (step 5). Harvest, classification, and verification run automatically.
- **`retro-analyst` is the evaluator; you are the optimizer-applier.** It verifies and proposes against the live files; only the main loop edits — mirroring the BA/plan-reviewer and the "only the implementer edits" split.
- **Bias toward fewer, higher-confidence changes.** A retro that proposes two real P1 fixes beats one that rewrites five agents on thin evidence. When unsure whether something is systemic, record it as one-off in the artifact and let it recur once more before changing an agent.
- **The definition of a good retro:** a future run of the same command, on a different work item, avoids a wall this run hit — because an agent prompt, template, or memory now carries the lesson.
