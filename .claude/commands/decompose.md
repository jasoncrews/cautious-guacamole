---
description: Decompose an Epic, Feature, or large requirement into a properly-sized, parent-linked Epic→Feature→PBI backlog in Azure DevOps
argument-hint: <epic-or-feature-id | description> [project]
---

Decompose **$ARGUMENTS** into a reviewed, parent-linked **Epic→Feature→PBI** hierarchy in Azure DevOps, using the `azure-devops-business-analyst` (optimizer) ↔ `plan-reviewer` (evaluator) loop. Project defaults to `<your-azure-devops-project>`.

You are the orchestrator and run in the main loop. Keep the user in the loop at the two human gates. The heavy lifting (drafting + review + creation) is the BA's job — delegate to it; don't hand-author work items yourself.

## Hard rules (non-negotiable)
- **Human-only approval, at every level.** Epics, Features, and PBIs are created in **New**. NEVER set any work item to Approved or any other state.
- **Existing parents are read-only.** If the input is an existing Epic/Feature id, decompose **under** it — never recreate it, change its state, or edit its fields.
- **No tasks, no effort.** Never create child Tasks or set story points / hours at any level.
- **PBIs are Markdown** via the `render-plan-artifact-markdown` skill; Features/Epics are small hand-authored Markdown bodies per `.claude/templates/feature-epic-template.md`.

## 1. Determine the input mode & confirm scope (human gate 1)
Inspect `$ARGUMENTS`:
- **An integer work-item id** → `existing-parent` mode. Fetch it (`wit_get_work_item`), confirm it's an **Epic** or **Feature** (if it's a PBI, stop and tell the user — PBIs are decomposed via `/implement-pbi`, not this command). Show its id, title, type, and current children (if any). Plan to decompose **under** it.
- **Free-text** → top-down. Decide the entry level from the size of the ask (`new-epic` for a multi-capability initiative, `new-feature` for one capability, `pbis-only` for a small ask). When ambiguous, ask.

**`/decompose`'s job is breadth** — splitting a larger ask into a right-sized, parent-linked tree and sequencing it; it confirms scope but does **not** run a deep user-story/AC interview. If the ask is really just **one PBI** whose requirements aren't pinned down yet, send the user to **`/new-pbi`** (which interviews for the user story + acceptance criteria) rather than forcing a single-node decomposition.

Show the user the proposed **decomposition target** (mode + parent) and a one-line intent, and confirm before drafting. If anything about scope/level is unclear, ask 2–3 targeted questions now.

## 2. Decompose, review, and create (delegate to the BA)
Invoke `azure-devops-business-analyst` via the Task tool. Pass it: the input (the requirement text or the verified existing parent's id+type), the project, and the chosen `decomposition_target.mode`. The BA will:
- draft a **hierarchical Plan Artifact** (`decomposition_target`, optional `epic`, `features[]`, PBIs with `parent` + `build_order`) applying the foundation-first vertical-slice heuristic,
- run the `plan-reviewer` loop (max 2 revision cycles) for hierarchy integrity + decomposition quality,
- and, **after the user approves creation (human gate 2)**, create the tree parent-before-child in **New**, parent-linked, in build order, and write the backlog guidance doc to `Data/Plans/feature-<id>-<slug>-backlog.md`.

Relay the BA's outcome:
- **Approved & created** → show the resulting tree (ids, titles, links, parent-child structure, build order). Note everything is in **New** awaiting human approval.
- **Failed to converge / rejected** → present the BA's summary + the reviewer findings and stop. Ask how to proceed.

Resilience: if the BA reports it could not invoke `plan-reviewer` itself (nested-subagent limitation), drive the loop yourself — take the BA's draft, invoke `plan-reviewer` via the Task tool, hand the verdict back for revision, repeat up to 2 cycles — then return to the BA for Phase-2 creation after the user approves.

## 3. Report
Summarize: the created Epic/Feature/PBI ids + links, the hierarchy tree, the build order, the backlog doc path, and any open questions for the human. Remind the user that **nothing is Approved** — they review/improve in Azure DevOps and approve; an Approved PBI then flows into `/implement-pbi`.

## Notes
- Two human gates: scope/target confirmation (step 1) and the BA's pre-creation approval (step 2). Everything between runs automatically.
- This complements `/new-pbi` (author a single PBI through a guided interview — reach for it when the ask is one PBI and you'd rather be asked the right questions than have scope inferred), `/refine-pbi` (improve one existing PBI in place), and `/implement-pbi` (build one Approved PBI). `/decompose` produces the backlog those operate on.
- The PBIs this produces are full-template PBIs (Gherkin + entities + AC) ready for the implementation pipeline; the foundation PBI (build_order 1) is the natural first `/implement-pbi` target.
