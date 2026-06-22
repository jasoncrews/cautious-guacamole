---
description: Turn a sprint-review meeting transcript into backlog actions — author new PBIs, refine existing ones, flag plan impacts — via the existing authoring engines, human-gated, nothing approved or committed.
argument-hint: <transcript-path | pasted notes> [project] [iteration]
---

Take the sprint-review transcript in **$ARGUMENTS** and turn what was said into concrete, reviewed backlog actions: new PBIs authored to the Markdown standard, in-place refinements of existing PBIs, recorded decisions, and flagged plan impacts — all created in **New**, human-gated, with nothing approved or committed.

You are the orchestrator and you run this in the **main loop** (so you can fan out the `sprint-review-analyst` agent — subagents can't spawn subagents). **Reuse the existing engines** — don't reinvent authoring: `sprint-review-analyst` (extract/classify), then `/new-pbi` ↔ `azure-devops-business-analyst` ↔ `plan-reviewer` for new items, the `/refine-pbi` flow for changes, and `/decompose` for anything bigger than one PBI. Keep the user in the loop at **two human gates**: confirm the action list, then approve the writes.

## Hard rules (the same guardrails as the rest of the pipeline)

- **Human-only New→Approved.** Everything created lands in **New**; a human is the only actor who approves. Refinements are **text-only** — never change `System.State`, children, or effort.
- **Don't invent scope.** Derive every action from what the transcript actually says, and **cite it**. A vague or aspirational comment is not a requirement — when intent is unclear, mark it an open question and ASK, or park it. Never fabricate acceptance criteria from a passing remark.
- **Authoring is PBI-terminal.** No tasks, no story points/hours, ever. (Task breakdown is sprint planning; implementation is `/implement-pbi`.)
- **Conservative matching.** Only treat an item as "change to existing PBI #N" when the match to a real work item is **verified**. Otherwise propose it as new and ask — don't silently edit the wrong PBI.
- **Comments are faithful records.** A recorded decision/FYI is attributed to the sprint review and quotes what was said — not your interpretation.
- **Never commit/push.** New items + in-place refinements + comments only; the digest is a tracked artifact left for review.

## Steps

### 1. Ingest the transcript
From `$ARGUMENTS`: a **file path** (Read it), pasted text, or "the notes above" (use the conversation). If nothing was supplied, ask for the transcript before continuing. Capture the **project** (default `<your-azure-devops-project>`), and — if the transcript states them — the **sprint/iteration** and the **PBIs that were demoed** (so feedback links to the right items). Show the user a one-line scope summary (source + project + iteration + #items demoed).

### 2. Extract & classify (fan out `sprint-review-analyst`)
Invoke `sprint-review-analyst` via the Task tool, passing the transcript (inline or path) + project + iteration. It returns a structured, **transcript-cited** action list, each item classified:
- **`new-pbi`** — a new capability/requirement that fits one PBI.
- **`new-feature`** — bigger than one PBI → route to `/decompose`.
- **`refine-existing`** — a change to an existing PBI (with the matched work-item id + `verified|inferred` confidence).
- **`bug`** — a defect surfaced in the demo → new PBI/Bug in **New**.
- **`plan-impact`** — an Approved / in-flight PBI whose behavior changed → its `.claude/plans/` plan needs re-running via `/implement-pbi`.
- **`comment`** — a decision/FYI to record on a work item, no new work.
- **`parking-lot`** — noted, not actioned (out of scope / needs more discussion).

It matches change/comment items to existing work items via ADO search and tags each match. It does **not** create or edit anything.

### 3. Gate 1 — confirm the action list
Show the user the classified list with each item's **transcript citation** and matched work-item id. **Ask them to accept / drop / reclassify**, supply any missing ids, and resolve ambiguous matches. Pin intent here — a comment that *could* be a new requirement is the user's call, not yours. Carry anything still unclear as an explicit open question.

### 4. Draft (reuse the authoring engines — don't create yet)
For each accepted item, prepare the change with the existing flow:
- **`new-pbi` / `bug`** → derive a brief from the transcript item (the transcript stands in for `/new-pbi`'s up-front interview — don't re-interview the user) and run the same orchestrator-owned loop `/new-pbi` uses after its interview: **invoke `azure-devops-business-analyst` via the `Task` tool in draft mode** with the brief, send the returned Plan Artifact to `plan-reviewer`, and on `needs_revision` re-invoke the BA in revise mode (cap: 2 cycles — you drive the loop; the BA can't spawn the reviewer itself). Draft only — no creation here.
- **`new-feature`** → don't author inline; recommend `/decompose <parent-id | description>` and, if the user agrees at the gate, run it.
- **`refine-existing`** → follow the `/refine-pbi` flow for that id: fetch it, build the refined Markdown **preserving all existing content** and deriving the change **only** from the transcript. Draft only.
- **`plan-impact`** → no draft; capture the PBI id + exactly what changed, for a `/implement-pbi` re-plan.
- **`comment`** → compose the attributed comment text (e.g. "Sprint review YYYY-MM-DD: <quote/decision>").

### 5. Gate 2 — approve the writes
Present the **full set of intended Azure DevOps writes**: new PBIs/Bugs (title + rendered Description + AC bullets + any parent), refinements (before→after per id), and comments (id + text). **Explicitly ask permission to write.** Wait for a yes. (You're creating/editing real backlog items — don't start without it.)

### 6. Apply
On approval:
- **Create** new PBIs/Bugs in **New** (parent-linked with `wit_work_items_link type:"parent"` if a parent was named), `format: "Markdown"` on Description + AcceptanceCriteria. Creation goes through `azure-devops-business-analyst` invoked in **create mode** (continue the same BA agent, stating the reviewer approved and the human confirmed at gate 2) — the only agent that writes to ADO.
- **Refine** existing PBIs in place (Description + AcceptanceCriteria, Markdown) — **no state, children, or effort changes**; verify the format flag persisted.
- **Comment** on named items with `wit_add_work_item_comment`.
- **Do NOT** create tasks/effort, change state, or auto-run `/implement-pbi`.

### 7. Save the digest + report
Write a tracked digest to `.claude/plans/sprint-review-<YYYY-MM-DD>-<slug>.md`: the source, the classified action list with transcript citations, what was **created** (ids), **refined** (ids + before→after summary), **commented**, the **plan-impact** items (PBI id + what changed → needs `/implement-pbi` re-plan), and the **parking-lot**. Report the same to the user with links. Remind them: new PBIs await human **New→Approved**, plan-impact PBIs need a `/implement-pbi` re-plan, and nothing was committed.

## Notes
- **Two human gates only:** confirm the action list (step 3) and approve the writes (step 5).
- **Output is indistinguishable from `/new-pbi` / `/refine-pbi`** — same template, same render skill, same `plan-reviewer` — because it dispatches to those engines rather than duplicating them.
- **Sprint reviews are noisy.** Bias toward fewer, well-evidenced actions: most discussion is context, not backlog work. Park what's vague; only author what the transcript clearly asks for.
- **Plans aren't rewritten here.** A `plan-impact` item is *flagged* for `/implement-pbi` to re-plan against the updated PBI — this command changes PBIs, not the TDD plans the planner owns.
