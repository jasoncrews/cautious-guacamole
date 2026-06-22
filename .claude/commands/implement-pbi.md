---
description: Plan, review, and TDD-implement a single Azure DevOps PBI in this repo using the sp3 implementation agents
argument-hint: <work-item-id> [project]
---

Implement Azure DevOps work item **$ARGUMENTS** end-to-end in this repo, using the pre-flight + research agents (`sp3-spec-validator`, `sp3-analog-scout`, `sp3-dependency-mapper`, `sp3-standards-rivet-researcher`, `sp3-legacy-analyst`) and the build agents (`sp3-implementation-planner`, `sp3-implementation-plan-reviewer`, `sp3-tdd-implementer`, `sp3-refactorer`, `sp3-rivet-ui-builder`, `sp3-hardener`).

If no work-item id was supplied, ask for it before continuing. Project defaults to `<your-azure-devops-project>` unless a second argument overrides it.

You are the orchestrator. Run these steps in order and keep the user in the loop at the confirmation gates. Do not write code yourself — delegate to the agents.

## 1. Confirm the target + size the problem

Fetch the work item (`wit_get_work_item`) and show the user: id, title, type, plain AC bullets, and Gherkin scenarios.

Then **assess the complexity tier** based on the PBI content and present your reasoning:

| Tier | Signals | Research agents | Plan-review cap | Hardener target |
|------|---------|-----------------|-----------------|-----------------|
| **S — Small** | Single entity, 1–3 AC bullets, standard CRUD verb, clear analog, no new permissions, no legacy path | analog-scout only | **1 cycle** | skip |
| **M — Medium** | 1–2 entities, 4–8 AC bullets, known pattern, standard list+form UI, possibly new permissions | scout + dep-mapper + standards-rivet* | **2 cycles** | 70% |
| **L — Large** | 2+ entities or complex business rules, 8+ AC bullets, cross-cutting concerns, significant UI, or legacy mapping | all applicable | **3 cycles** | 80% |
| **XL — Epic** | Architecture-level change, new subsystem, no clear analog, 10+ AC bullets, external integration | all applicable + extra care | **3 cycles (show user each revision)** | 85% |

*(* standards-rivet only when the PBI will have ui_tasks; skip for API-only)*

Show the user your tier assessment and 2–3 sentences of reasoning. **Ask them to confirm the tier or override it.** The confirmed tier is recorded and governs every subsequent pipeline decision. If they override, record their tier and note the override in the research digest.

## 1.5. Spec-validate (always — before research)

Invoke `sp3-spec-validator` via the Task tool, passing the PBI id.

- **`ready`** (zero blocking gaps) → continue to step 2. Log any advisory gaps into the research digest as notes for the planner.
- **`needs_clarification`** (one or more blocking gaps) → present the gaps clearly to the user. Ask whether they want to: **(a)** update the PBI in ADO and you re-run the validator, or **(b)** override and proceed with the gaps noted as open questions for the planner. **Do NOT proceed without user input on a blocking verdict.**

The spec-validator is a fast pre-flight check — do not skip it, even for S-tier PBIs.

## 2. Research (parallel fan-out — orchestrator-owned)

Ground the plan before the planner runs. Subagents can't spawn subagents, so **you** (the main loop) fan the research agents out — issue the applicable ones as **multiple `Task` calls in a single message** so they run in parallel. Pass each the PBI content (title, description, Gherkin, AC, entity blocks) inline.

Gate which agents run by the **confirmed tier** (not just PBI content):

| Agent | S | M | L | XL | Override |
|-------|---|---|---|----|---------|
| `sp3-analog-scout` | ✓ | ✓ | ✓ | ✓ | Always |
| `sp3-dependency-mapper` | — | ✓ | ✓ | ✓ | Also run for S if the PBI modifies an existing entity, touches permissions, or requires a migration |
| `sp3-standards-rivet-researcher` | if UI | if UI | if UI | if UI | Only when plan will have ui_tasks |
| `sp3-legacy-analyst` | — | — | if legacy | if legacy | Only when a legacy source path is in scope AND no persisted analysis exists (see below) |

**Legacy research is artifact-first.** When a legacy module/path is in scope, first Glob `.claude/plans/legacy-<module-slug>/` — if `analysis-digest.md` exists there, **read it (plus the relevant phase artifacts) directly into the research digest** under the legacy heading, citing the artifact paths and their frontmatter `generated` dates; do NOT dispatch an agent. Only if no persisted analysis exists, dispatch `sp3-legacy-analyst` with `phase: scoped-recon`, the legacy path, and the PBI content. (For a large legacy scope, suggest the user run `/analyze-legacy` first — it persists the full analysis for every later PBI.)

Each returns a Markdown report with claims tagged `verified | from-memory(date) | inferred`. Assemble the reports **verbatim** under labeled `##` headings (structured pass-through — do not summarize away signal). Flag any **contradictions** between agents in a `## Contradictions to resolve` section for the planner — never silently pick a winner. Write the digest to `.claude/plans/pbi-<id>-<short-slug>-research.md`, leading with a link to the work item and the confirmed tier. Append advisory spec-validator gaps as a `## Spec notes for planner` section. Each research agent writes durable findings to **its own** agent-memory dir (no write race) — confirm they did or note "none".

## 3. Plan (orchestrator-owned evaluator-optimizer loop)

Invoke `sp3-implementation-planner` via the Task tool, passing the work-item id, project, and research-digest path.

**You drive the loop — the planner cannot invoke the reviewer itself (subagents can't spawn subagents):**

1. Take the planner's saved draft and invoke `sp3-implementation-plan-reviewer` via Task, passing the plan-file path.
2. **Primary exit — `approved` verdict** (zero blocker/issue findings; only suggestions) → proceed to step 4.
3. **Revision loop** — reviewer returns `needs_revision` → re-invoke the planner with the plan-file path and the reviewer's verdict. Apply the safety cap by tier:
   - **S: cap = 1 revision cycle.** After 1 failed cycle → escalate to user.
   - **M: cap = 2 revision cycles.** After 2 failed cycles → escalate to user.
   - **L/XL: cap = 3 revision cycles.** XL additionally shows the user the reviewer verdict before re-invoking the planner — wait for their go-ahead each time.
4. **`rejected` verdict** → stop immediately, present findings to the user, do not re-invoke.
5. **Escalation** (cap reached without `approved`) → present the planner summary + reviewer findings; ask how the user wants to proceed. **Do not self-approve.**

The cap is a hard stop; never exceed it.

## 4. Approval gate

Show the approved plan's human summary: layers touched, number of tests planned, AC→test coverage confirmation. **Explicitly ask permission to implement.** Wait for confirmation. Implementation creates a branch and edits the working tree — do not start without a yes.

## 4.5. Create child Tasks (sprint-planning fallback — orchestrator-owned)

Fill the task-breakdown gap only if the team hasn't already:
1. Re-fetch the PBI with relations (`wit_get_work_item`, expand `relations`); look for existing child Task work items.
2. **If child Tasks exist** → the team did the breakdown in planning. Create none; list the existing Tasks and move on.
3. **If there are none** → derive a small set of Tasks from the approved plan: one per `layers[]` entry (data / application / api / shared / bff / ui), plus a "Tests" Task, plus a "UI" Task when the plan has `ui_tasks`. For each: `wit_create_work_item` `workItemType: "Task"` in **New**; parent-link with `wit_work_items_link` (`type: "parent"`, `linkToId` = PBI id). Title + one-line Description from the layer's `purpose` only — **never set effort fields** (story points, hours, activity).
4. Not a human gate — runs automatically under the approved plan. You (the main-loop orchestrator) create these directly; the implementer and the other agents never write to Azure DevOps.

## 5. Implement the backend (TDD)

The approved planner saved the plan as Markdown to `.claude/plans/pbi-<id>-<short-slug>.md` (it links back to the work item). Invoke `sp3-tdd-implementer` via Task, passing the plan-file path and work-item id. It:
- Creates `feature/pbi-<id>`,
- Works red→green→refactor (micro-level: naming, private-method extractions within a file) across backend/BFF layers (entities, migrations, CQRS, Application.Api controllers, Shared DTOs, Refit interfaces, BFF/Online server controllers),
- Defers `.razor` UI to sp3-rivet-ui-builder,
- Leaves the plan file in place and leaves changes **uncommitted**.

If the implementer reports unresolved **backend** criteria, surface them and stop. Do not proceed to the refactor step with open backend rows.

## 6. Refactor pass

Invoke `sp3-refactorer` via Task, passing the plan-file path and work-item id. It works on the same `feature/pbi-<id>` branch and runs one structural pass:
- Duplication reduction across the module's files
- Method/class size enforcement (extracts private helpers)
- Magic string/number extraction to `<Module>Constants.cs`
- Property-based edge-case tests for collection handlers

It does not change API contracts and does not build UI. If the refactorer reports reverted refactors or test failures, surface them and wait for user input before continuing.

## 7. Build the UI (only if the plan has `ui_tasks`)

If the approved plan contains `ui_tasks`, invoke `sp3-rivet-ui-builder` via Task, passing the plan-file path and work-item id. It works on the same `feature/pbi-<id>` branch, builds the `.razor` pages to convention with verified Rivet components, and records manual-verification steps for each UI-traced criterion. Skip entirely for API-only plans (no `ui_tasks`).

## 8. Harden (skip for S tier)

For **M, L, and XL tiers only**: invoke `sp3-hardener` via Task, passing the plan-file path, work-item id, and the confirmed problem tier. It:
- Runs Stryker.NET mutation testing scoped to PBI-touched files,
- Patches tests to kill surviving mutants,
- Hard cap: **2 Stryker rounds maximum** regardless of kill rate.

Kill-rate targets: M=70%, L=80%, XL=85%. If the kill rate is below target after 2 rounds, the hardener reports it as an advisory shortfall — it does not block delivery but must be surfaced in the final report.

## 9. Report

Assemble and relay the combined report:
- Branch name and saved plan path
- Confirmed problem tier (S/M/L/XL) and how it shaped the pipeline (which agents ran, what caps were in effect)
- Child Tasks: created in step 4.5, or pre-existing team breakdown
- Full AC/scenario coverage matrix (each item → covering test for backend rows, or page + manual-verification step for UI rows)
- Refactorer summary: what was cleaned up, what was reverted and why
- Hardener summary (if run): final kill rate vs. target, round count, advisory shortfall if any
- Files changed by layer, migrations added
- Build + test output summaries
- Anything unresolved, surfaced plainly
- Reminder: changes (including `.claude/plans/` artifacts) are uncommitted on `feature/pbi-<id>`; UI pages need manual in-browser verification; commit/push/PR is the human's next step

## Notes

- **Human gates:** target + tier confirmation (step 1), any spec-validator `needs_clarification` pause (step 1.5 — only on blocking gaps), pre-implementation approval (step 4), and XL-tier plan revision visibility. Everything else runs automatically.
- **Safety caps are non-negotiable.** S=1, M=2, L/XL=3 plan-review cycles. Hardener=2 Stryker rounds. Never exceed.
- **Quality is the primary exit signal; the cap is the safety net.** Loops exit on `approved` / target-met. The cap prevents infinite loops, not good-enough work.
- **Tasks are a fallback, not a default.** Only create child Tasks when sprint planning hasn't already broken the PBI down. Created Tasks are always **New** with no effort fields.
- **Unresolved backend criteria never get papered over.** Surface them plainly; let the user decide whether to re-plan, answer an open question, or accept partial delivery.
- The PBI's acceptance criteria + Gherkin scenarios are the definition of done throughout — not "the plan executed."
