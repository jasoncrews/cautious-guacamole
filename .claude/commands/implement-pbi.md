---
description: Plan, review, and TDD-implement a single Azure DevOps PBI in this repo using the sp3 implementation agents
argument-hint: <work-item-id> [project]
---

Implement Azure DevOps work item **$ARGUMENTS** end-to-end in this repo, using the research agents (`sp3-analog-scout`, `sp3-dependency-mapper`, `sp3-standards-rivet-researcher`, `sp3-legacy-explorer`) and the build agents (`sp3-implementation-planner`, `sp3-implementation-plan-reviewer`, `sp3-tdd-implementer`, `sp3-rivet-ui-builder`).

If no work-item id was supplied, ask for it before continuing. Project defaults to `<your-azure-devops-project>` unless a second argument overrides it.

You are the orchestrator. Run these steps in order and keep the user in the loop at the two confirmation gates. Do not write code yourself — delegate to the agents.

## 1. Confirm the target
Fetch the work item (`wit_get_work_item`) and show the user its id, title, type, the plain acceptance-criteria bullets, and the Gherkin acceptance scenarios from the description. Ask the user to confirm this is the PBI to implement. If it's a Feature, list its child PBIs and confirm scope (one PBI at a time is preferred).

## 1.5. Research (parallel fan-out — you own this, in the main loop)
Ground the plan before the planner runs. Subagents can't spawn subagents, so **you** (the main loop) fan the research agents out — issue the applicable ones as **multiple `Task` calls in a single message** so they run in parallel. Pass each the PBI content (title, description, Gherkin, AC, entity blocks) inline.

Gate which agents run by the PBI (don't pay for ones that don't apply):
- **`sp3-analog-scout`** — almost always (it short-circuits to the memory analog for standard CRUD).
- **`sp3-dependency-mapper`** — when the PBI has entity blocks, modifies an existing entity, or touches permissions/migrations.
- **`sp3-standards-rivet-researcher`** — only when the PBI involves UI (pages/components likely → `ui_tasks`). Skip for API-only PBIs.
- **`sp3-legacy-explorer`** — only when a legacy source path is in scope (a legacy module being replicated / referenced). Skip otherwise.

Each returns a Markdown report with claims tagged `verified | from-memory(date) | inferred`. Then:
1. Assemble the reports **verbatim** under labeled `##` headings (structured pass-through — do not summarize away signal). Flag any **contradictions** between agents in a `## Contradictions to resolve` section for the planner — never silently pick a winner.
2. Write the digest to **`StarterPack3.Application.Api/Data/Plans/pbi-<id>-<short-slug>-research.md`**, leading with a link to the work item. It is a tracked, shared artifact (sibling to the plan) reviewed in the PR.
3. Persist any durable findings the agents *proposed*: each research agent writes to **its own** agent-memory dir, so there's no write race — just confirm they did (or note "none").

## 2. Plan (with review loop)
Invoke `sp3-implementation-planner` via the Task tool, passing the work-item id, project, **and the research-digest path from step 1.5**. The planner consumes the digest under its trust model (trusts `verified`, spot-checks `from-memory`, re-verifies `inferred`), drafts an Implementation Plan Artifact, and runs `sp3-implementation-plan-reviewer` (max 2 revision cycles).

Relay the planner's outcome:
- **Approved plan** → continue to step 3.
- **Failed to converge / rejected** → present the planner's summary and the reviewer findings to the user and stop. Ask how they want to proceed.

Resilience: if the planner reports it could not invoke `sp3-implementation-plan-reviewer` itself (a nested-subagent limitation), drive the loop yourself — take the planner's draft, invoke `sp3-implementation-plan-reviewer` via the Task tool, hand the verdict back to the planner for revision, and repeat up to 2 cycles.

## 3. Approval gate
Show the user the approved plan's human summary: the layers touched, the number of tests planned, and the AC→test coverage confirmation. **Explicitly ask permission to implement.** Wait for confirmation. (Implementation creates a branch and edits the working tree — don't start without a yes.)

## 3.5. Create child Tasks (sprint-planning fallback — orchestrator-owned)
A PBI's task breakdown is normally a **sprint-planning** activity the team owns. Fill that gap **only if they haven't**:
1. Re-fetch the PBI with its relations (`wit_get_work_item`, expand `relations`) and look for existing child **Task** work items (child links pointing at items of type `Task`).
2. **If child Tasks already exist** → the team did the breakdown in planning. Create none; list the existing Tasks and move on.
3. **If there are none** → derive a small set of Tasks from the **approved plan**: one per `layers[]` entry (data / application / api / shared / bff / ui), plus a "Tests" Task, plus a "UI" Task when the plan has `ui_tasks`. For each: `wit_create_work_item` `workItemType: "Task"` in **New**, with a one-line Description from the layer's `purpose`; then parent-link it with `wit_work_items_link` (`type: "parent"`, `linkToId` = the PBI id).
   - **No effort, ever.** Never set story points, estimated/remaining hours, or activity — those are human-set in planning. Title + description + parent link only.
   - **You (the main-loop orchestrator) create these directly** — the implementer and the other agents never write to Azure DevOps.
4. This is **not** a new human gate: it runs automatically under the already-approved plan and creates nothing but New Tasks under the PBI. Report the Tasks (created vs. pre-existing) in step 6.

## 4. Implement the backend (TDD)
The approved planner saved the plan as Markdown to `StarterPack3.Application.Api/Data/Plans/pbi-<id>-<short-slug>.md` (it links back to the work item). On approval, invoke `sp3-tdd-implementer` via the Task tool, passing **that plan-file path** and the work-item id. The implementer:
- creates `feature/pbi-<id>`,
- works red→green→refactor through the backend/BFF layers (entities, migrations, CQRS, Application.Api controllers, Shared DTOs, Refit interfaces, BFF/Online server controllers),
- defers the Blazor client `.razor` UI (marks UI-traced criteria "→ sp3-rivet-ui-builder"),
- leaves the plan file in place (it's a shared, tracked artifact),
- and does NOT commit, push, open a PR, or modify the work item.

If the implementer reports unresolved **backend** criteria, surface them and stop before the UI step — don't paper over them.

## 5. Build the UI (only if the plan has `ui_tasks`)
If the approved plan contains `ui_tasks`, invoke `sp3-rivet-ui-builder` via the Task tool, passing **the same plan-file path** and the work-item id. It works on the same `feature/pbi-<id>` branch the implementer created, builds the `.razor` pages to convention with verified Rivet components, and records manual-verification steps for each UI-traced criterion. Skip this step entirely for API-only plans (no `ui_tasks`).

## 6. Report
Assemble and relay the combined report from both agents: branch name, the saved plan path, the child **Tasks** (created in step 3.5, or noting the team's pre-existing ones), the **full** AC/scenario coverage matrix (each item → its covering test for backend rows, or its page + manual-verification steps for UI rows), files changed by layer, migrations added, the build + test output summaries, and anything unresolved. Remind the user the changes (including the plan doc in `Data/Plans/`) are uncommitted on `feature/pbi-<id>` and awaiting their review — they commit/push when satisfied, the plan travels with the PR, and UI pages still need manual in-browser verification.

## Notes
- Two human gates only: target confirmation (step 1) and the pre-implementation approval (step 3). Everything else — research, planning, **child-Task creation (step 3.5)**, and implementation — runs automatically.
- **Tasks are a fallback, not a default.** Only create them when the PBI has no child Tasks; if sprint planning already broke it down, leave that breakdown alone. Created Tasks are always **New** with no effort fields — humans estimate and schedule.
- If the implementer stops with unresolved acceptance criteria, surface them plainly; do not re-run blindly. The user decides whether to re-plan, answer an open question, or accept partial delivery.
- The PBI's acceptance criteria + Gherkin scenarios are the definition of done throughout — not "the plan executed."
