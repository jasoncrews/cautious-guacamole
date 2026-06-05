---
description: Plan a legacy-module replication as a parent-linked Feature → increasing-complexity PBIs in Azure DevOps, following the StarterPack V3 CRUD guide
argument-hint: <module-name> <legacy-repo-path>
---

Replicate the legacy module **{first argument}** (legacy source at **{remaining arguments — absolute path}**) into this repo as a reviewed, parent-linked **Feature → PBI** backlog in Azure DevOps. This is a legacy-aware specialization of `/decompose`: it adds a legacy-exploration pass up front, then runs the **same** `azure-devops-business-analyst` (optimizer) ↔ `plan-reviewer` (evaluator) loop and the **same** creation rules. Project defaults to `<your-azure-devops-project>`.

If either the module name or the legacy repo path is missing, ask for it before continuing.

You are the orchestrator and run in the main loop. Keep the user in the loop at the two human gates. Delegate the heavy lifting (exploration, drafting, review, creation) to the agents — don't hand-author work items yourself.

## Hard rules (non-negotiable — identical to `/decompose`)
- **Human-only approval.** The Feature and every PBI are created in **New**. NEVER set any work item to Approved or any other state.
- **No tasks, no effort.** Never create child Tasks or set story points / hours at any level. (Task breakdown is the sprint-planning / `/implement-pbi` fallback, not authoring.)
- **PBIs are Markdown** via the `render-plan-artifact-markdown` skill; the Feature is a small hand-authored Markdown body per `.claude/templates/feature-epic-template.md`.
- **Parent-link with `wit_work_items_link` (`type: "parent"`), parent created before child.** NEVER `wit_add_child_work_items` (it can't set the AcceptanceCriteria field, tags, or the rendered Markdown body).

## Legacy-specific guidance (fold into the plan)
- **Follow the StarterPack V3 CRUD guide:** https://uisapp2.iu.edu/confluence-prd/spaces/EAS/pages/755697093/Creating+StarterPack+V3+CRUD — if it's unreachable (on-prem Confluence / auth-gated), fall back to the **`StarterPack3`** reference repo (project `EA-StarterPack3`) via the Azure DevOps MCP, and to the closest existing CRUD module in your own repo.
- **Permissions are role/group based** — standard StarterPack approach (policies in the UI projects' `Permissions.cs`, gated via `[Authorize(Policy = "...")]`). Nothing custom.
- **Prefer constants over lookup tables.** Where the legacy app uses lookup/control tables, prefer **constants files** in `<App>.Shared` (mirroring an existing `*Constants.cs`) to reduce admin work. Use a real entity only when the data has a live source (e.g. backed by an external/federated data integration) or churns often enough to warrant a maintenance UI — flag any borderline cases as open questions.

## 1. Explore the legacy module (then confirm scope — human gate 1)
Invoke `sp3-legacy-explorer` via the Task tool with the module name + legacy repo path. It returns a verification-tagged Markdown summary of the legacy pages, entities (candidate keys / FKs), business logic, and workflows, plus the recommended StarterPack3 analog and SP3 deltas — without dumping file contents. (For a large module, you may fan out one `sp3-legacy-explorer` per sub-area in parallel.)

Show the user: the legacy summary, the proposed **decomposition target** (`new-feature` — a Feature parenting the PBIs), and the proposed PBI sequence (see below). Confirm scope before drafting. Ask 2–3 targeted questions if scope/level is unclear.

## 2. Decompose, review, and create (delegate to the BA)
Invoke `azure-devops-business-analyst` via the Task tool. Pass it: the legacy-explorer summary, the project, `decomposition_target.mode = "new-feature"`, and the legacy-specific guidance above. The BA will:
- draft a **hierarchical Plan Artifact** — a Feature plus child PBIs that **increase in complexity**, applying the foundation-first vertical-slice heuristic:
  - **PBI 1 (foundation, `build_order: 1`):** base area scaffold + core CRUD + data model (all FK children) + one migration + seed.
  - **PBI 2+:** each adds one logical capability (lookup constants, online submission UI, junction tables, attachments, workflow, notifications, claims / sub-modules, search / export, …), independently shippable where possible.
  - aggregating / dashboard PBIs last.
- run the `plan-reviewer` loop (max 2 revision cycles) for hierarchy integrity + decomposition quality,
- and, **after the user approves creation (human gate 2)**, create the Feature + PBIs parent-before-child in **New**, parent-linked, in build order, rendering PBIs via `render-plan-artifact-markdown`, and write the backlog guidance doc to `Data/Plans/feature-<id>-<slug>-backlog.md`.

Relay the BA's outcome:
- **Approved & created** → show the tree (ids, titles, links, build order). Note everything is in **New** awaiting human approval.
- **Failed to converge / rejected** → present the BA's summary + reviewer findings and stop. Ask how to proceed.

Resilience: if the BA reports it could not invoke `plan-reviewer` itself (nested-subagent limitation), drive the loop yourself — take the BA's draft, invoke `plan-reviewer` via the Task tool, hand the verdict back for revision, repeat up to 2 cycles — then return to the BA for Phase-2 creation after the user approves.

## 3. Report
Summarize: the created Feature + PBI ids and links, the hierarchy tree, the build order, the backlog doc path, and any open questions (especially constants-vs-entity calls flagged in step 1). Remind the user that **nothing is Approved** — they review/improve in Azure DevOps and approve; an Approved PBI (starting with the foundation) then flows into `/implement-pbi`.

## Notes
- Two human gates: scope confirmation after legacy exploration (step 1) and the BA's pre-creation approval (step 2). Everything between runs automatically.
- This is `/decompose` with a legacy-exploration front end and the StarterPack CRUD guidance — same conventions, same Markdown render skill, same parent-linking, same human-only New→Approved.
