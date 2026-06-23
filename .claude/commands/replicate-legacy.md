---
description: Author a legacy-module replication as a parent-linked Feature → increasing-complexity PBIs in Azure DevOps from a /analyze-legacy artifact folder, following the StarterPack V3 CRUD guide
argument-hint: <module-name> [legacy-repo-path]
---

Replicate the legacy module **{first argument}** into this repo as a reviewed, parent-linked **Feature → PBI** backlog in Azure DevOps, **from the analysis artifacts** in `.claude/plans/legacy-<module-slug>/` (produced by `/analyze-legacy`, the head of the chain). This is the authoring half of the legacy chain: it consumes the analysis digest and runs the **same** `azure-devops-business-analyst` (optimizer) ↔ `plan-reviewer` (evaluator) loop and the **same** creation rules as `/decompose`. Project defaults to `<your-azure-devops-project>`. The optional second argument (legacy repo path) is only needed if the analysis hasn't been run yet.

If the module name is missing, ask for it before continuing.

> **SP3 reference source.** Canonical StarterPack V3 conventions and code examples live in the **`StarterPack3`** repo (Azure DevOps project **`EA-StarterPack3`**). The SP3 patterns this command asserts (permissions, constants, CRUD shape) are reference-app starting points — the agents verify them against that repo via the Azure DevOps MCP; the consuming app has its own project prefix.

You are the orchestrator and run in the main loop. Keep the user in the loop at the two human gates. Delegate the heavy lifting (drafting, review, creation) to the agents — don't hand-author work items yourself.

## Hard rules (non-negotiable — identical to `/decompose`)
- **Human-only approval.** The Feature and every PBI are created in **New**. NEVER set any work item to Approved or any other state.
- **No tasks, no effort.** Never create child Tasks or set story points / hours at any level. (Task breakdown is the sprint-planning / `/implement-pbi` fallback, not authoring.)
- **PBIs are Markdown** via the `render-plan-artifact-markdown` skill; the Feature is a small hand-authored Markdown body per `.claude/templates/feature-epic-template.md`.
- **Parent-link with `wit_work_items_link` (`type: "parent"`), parent created before child.** NEVER `wit_add_child_work_items` (it can't set the AcceptanceCriteria field, tags, or the rendered Markdown body).

## Legacy-specific guidance (fold into the plan)
- **Follow the StarterPack V3 CRUD guide:** https://uisapp2.iu.edu/confluence-prd/spaces/EAS/pages/755697093/Creating+StarterPack+V3+CRUD — if it's unreachable (on-prem Confluence / auth-gated), fall back to the **`StarterPack3`** reference repo (project `EA-StarterPack3`) via the Azure DevOps MCP, and to the closest existing CRUD module in your own repo.
- **Permissions are role/group based** — standard StarterPack approach: permission constants in the UI projects' `Permissions.cs`, enforced via role-based `[Authorize(Roles = "...")]` (the reference app uses **Roles**, not `Policy =` — verify your app's idiom via MCP before asserting). Nothing custom.
- **Prefer constants over lookup tables.** Where the legacy app uses lookup/control tables, prefer **constants files** in `<App>.Shared` (mirroring an existing `*Constants.cs`) to reduce admin work. Use a real entity only when the data has a live source (e.g. backed by an external/federated data integration) or churns often enough to warrant a maintenance UI — flag any borderline cases as open questions. The digest's constants-vs-entity flag table is the starting point.

## 0. Locate the analysis artifacts (then confirm scope — human gate 1)
Glob `.claude/plans/legacy-<module-slug>/analysis-digest.md` (slug = kebab-case module name).

- **Missing** → the analysis hasn't run. **Stop and tell the user** to run **`/analyze-legacy <module> <legacy-repo-path>`** first (it is a command, not a skill — it has its own scope gate and writes the digest this command consumes), then re-run `/replicate-legacy <module>`. Ask for the legacy repo path if it wasn't provided.
- **Present** → check `progress.md` / `coverage-report.md` for unresolved **critical** gaps or `partial` artifacts; surface them to the user rather than silently authoring over holes.

Show the user the digest: executive summary, recommended StarterPack3 analog + SP3 deltas, the constants-vs-entity flag table, open questions, the proposed PBI sequence seed, and the coverage scores. Confirm the **decomposition target** (`new-feature` — a Feature parenting the PBIs) and scope before drafting. Ask 2–3 targeted questions if scope/level is unclear.

## 1. Decompose and review (orchestrator-owned evaluator-optimizer loop)
**You drive the loop — the BA cannot invoke `plan-reviewer` or talk to the user itself (subagents can't spawn subagents or ask questions):**

1. Invoke `azure-devops-business-analyst` via the Task tool in **draft mode**. Pass it: the **paths** to `analysis-digest.md` and the artifact folder (the BA has Read — pass paths, not pasted bodies), the project, `decomposition_target.mode = "new-feature"`, and the legacy-specific guidance above. It returns a **hierarchical Plan Artifact** — a Feature plus child PBIs that **increase in complexity**, applying the foundation-first vertical-slice heuristic (the digest's PBI sequence seed is the starting point, not the answer):
   - **PBI 1 (foundation, `build_order: 1`):** base area scaffold + core CRUD + data model (all FK children) + one migration + seed.
   - **PBI 2+:** each adds one logical capability (lookup constants, online submission UI, junction tables, attachments, workflow, notifications, claims / sub-modules, search / export, …), independently shippable where possible.
   - aggregating / dashboard PBIs last.
2. Invoke `plan-reviewer` via the Task tool with the full Plan Artifact for hierarchy integrity + decomposition quality; it returns a structured Review Verdict.
3. **`approved`** → go to step 2 (human gate 2). **`needs_revision`** → re-invoke the BA in **revise mode** (continue the same BA agent via SendMessage when possible; otherwise re-invoke passing the full artifact + verdict), then re-review. **Cap: 2 revision cycles / 3 drafts** — hard stop.
4. **`rejected`** or cap reached without approval → present the BA's latest artifact + every iteration's reviewer findings and stop. Ask how to proceed. **Never self-approve.**

## 2. Approve and create (human gate 2)
Show the user the approved plan's summary: the Feature + PBI titles, build order, and open questions (especially constants-vs-entity calls). **Explicitly ask permission to create.** Wait for a yes.

On approval, invoke the BA in **create mode** (continue the same agent, stating that the reviewer approved and the human confirmed). It creates the Feature + PBIs parent-before-child in **New**, parent-linked, in build order, rendering PBIs via `render-plan-artifact-markdown`, and writes the backlog guidance doc to `.claude/plans/feature-<id>-<slug>-backlog.md`. Relay its outcome: the tree (ids, titles, links, build order), noting everything is in **New** awaiting human approval — or any partial failures exactly as reported.

## 3. Report
Summarize: the created Feature + PBI ids and links, the hierarchy tree, the build order, the backlog doc path, and any open questions (especially constants-vs-entity calls from the digest). Remind the user that **nothing is Approved** — they review/improve in Azure DevOps and approve; an Approved PBI (starting with the foundation) then flows into `/implement-pbi`, whose research phase reads the same `.claude/plans/legacy-<module-slug>/` artifacts directly.

## Notes
- Two human gates: digest/scope confirmation (step 0) and the BA's pre-creation approval (step 2). Everything between runs automatically.
- This is `/decompose` fed by `/analyze-legacy` artifacts plus the StarterPack CRUD guidance — same conventions, same Markdown render skill, same parent-linking, same human-only New→Approved.
- The phased analysis itself (inventory, parallel lenses, coverage validation, synthesis) lives in `/analyze-legacy` — this command never re-analyzes when a digest exists; re-run `/analyze-legacy` (refresh) if the legacy app changed.
