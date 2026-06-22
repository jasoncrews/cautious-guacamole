---
description: Run the phased legacy-module analysis pipeline (herman-documenter methodology) — inventory → five parallel analysis lenses → coverage validation → synthesis — producing tracked Markdown artifacts in .claude/plans/legacy-<module-slug>/
argument-hint: <module-name> <legacy-repo-path>
---

Analyze the legacy module **{first argument}** (legacy source at **{remaining arguments — absolute path}**) into a complete, coverage-validated set of Markdown analysis artifacts under `.claude/plans/legacy-<module-slug>/` (slug = kebab-case module name). This command is the **head of the legacy-replication chain**: its artifacts feed `/replicate-legacy` (backlog authoring) and `/implement-pbi` (research). It performs **analysis only** — no Azure DevOps writes, no work items, no code.

If either the module name or the legacy repo path is missing, ask for it before continuing.

> **SP3 reference source.** Canonical StarterPack V3 conventions live in the **`StarterPack3`** repo (Azure DevOps project **`EA-StarterPack3`**). The legacy→SP3 mapping this pipeline produces (recommended analog, constants-vs-entity calls, SP3 deltas) is grounded by the analyst fetching real patterns from that repo via the Azure DevOps MCP — this pack carries **no** local `conventions.md`. The consuming app has its own project prefix; the `StarterPack3.*` names are reference-app starting points.

You are the orchestrator and run in the main loop. Delegate every analysis phase to `sp3-legacy-analyst` and the validation to `sp3-legacy-coverage-validator` via the Task tool — don't hand-author artifacts yourself. You own exactly one artifact: `progress.md` (the per-phase checklist that makes runs resumable).

## Hard rules (non-negotiable)
- **Agents are leaves; you own all fan-out and loops** (subagents cannot spawn subagents).
- **One artifact per agent run**, at the `output_path` you pass. You write only `progress.md`.
- **Coverage gap-fix cycles: 2 max.** Hitting the cap escalates to the human — never self-resolved.
- **Scope cut:** doc-site generation (Docusaurus/polish phases of herman-documenter) is permanently out of scope — the analysis artifacts ARE the deliverable, consumed by the BA/planner pipeline, not end users.
- Artifacts are **tracked** in `.claude/plans/` and PR-reviewed; never gitignore or auto-delete them.

## 0. Resume check
Glob `.claude/plans/legacy-<module-slug>/`. If `progress.md` exists there, read it and show the user the per-phase status, then offer: **resume** (run only missing/`partial` phases, continuing from the first incomplete pipeline step below), **refresh** (re-run everything; prior artifacts are overwritten), or **abort**. If the `legacy_path` recorded in `progress.md` differs from the argument, warn before resuming. On a fresh run, create the folder's `progress.md` (module, legacy path, date, phase checklist: inventory / data-model / roles / process / business-rules / ui-flows / coverage / synthesis / markdown-qa — all pending). Keep `progress.md` updated as each step completes.

## 1. Inventory (foundation) — then confirm scope (human gate)
Invoke `sp3-legacy-analyst` via Task with `phase: inventory`, the module, legacy path, and `output_path: .claude/plans/legacy-<module-slug>/inventory.md`. It produces the categorized source-file inventory — the master checklist every later phase (and the coverage validator) works from.

Show the user: category counts, tech stack, entry points, and the inventory's Coverage-verification gaps. **Confirm scope before fanning out** — which directories/sub-areas are in or out (a wrong inventory poisons five parallel runs). Record confirmed exclusions in `progress.md`. Ask 2–3 targeted questions if scope is unclear.

## 2. Analysis fan-out (parallel ×5)
Issue **five Task calls in a single message** to `sp3-legacy-analyst` — phases `data-model`, `roles`, `process`, `business-rules`, `ui-flows` — each with the module, legacy path, `inventory_path`, and its own `output_path` (`data-model.md`, `roles.md`, `process.md`, `business-rules.md`, `ui-flows.md`). Update `progress.md` as each returns (note any `status: partial`). For a very large module you may additionally split `business-rules`/`ui-flows` by inventory category — still your fan-out, never an agent's.

## 3. Coverage validation loop (≤2 fix cycles)
Invoke `sp3-legacy-coverage-validator` via Task with the module, legacy path, artifact folder, and `cycle` number. It writes `coverage-report.md` and returns a JSON verdict.

- **`complete`** → proceed to synthesis.
- **`gaps_found`** →
  - For each `critical` gap: re-dispatch a **targeted** `sp3-legacy-analyst` run (one per affected phase, in parallel where phases differ) passing the gap's `fix_scope` — the analyst re-examines those legacy files and patches its artifact in place.
  - For each `over_documentation` finding: re-dispatch a targeted `sp3-legacy-analyst` run for the affected phase, passing the `artifact` path and the `claim` to retract/correct (this finding type carries **no** `fix_scope` — the analyst already knows the code and must remove the unsupported claim).
  Then re-validate (`cycle` + 1).
- **Cap (2 fix cycles) hit with critical gaps remaining** → stop and escalate: show the user the residual gaps and ask **proceed with documented gaps** (they stay visible in `coverage-report.md` and the digest) or **stop here**. Never silently proceed.

`minor` gaps never trigger a cycle — they stay recorded in `coverage-report.md`.

## 4. Synthesis
Invoke `sp3-legacy-analyst` with `phase: synthesis` and `output_path: .claude/plans/legacy-<module-slug>/analysis-digest.md`. It reads the six artifacts + `coverage-report.md` (and fetches SP3 conventions from the `StarterPack3` repo via the Azure DevOps MCP) and produces the digest: executive summary, recommended StarterPack3 analog + SP3 deltas, the constants-vs-entity flag table, migration/seed needs, consolidated open questions, a foundation-first PBI sequence seed, and residual coverage gaps.

## 5. Markdown QA (deterministic — no agent)
Invoke the `markdown-qa` skill on the artifact folder (list normalization, bold spacing, cross-artifact link validation). Report what it fixed and any broken links. If `node` is unavailable, skip with a warning — hygiene never blocks the run.

## 6. Report
Summarize: the artifact folder path and its contents, coverage scores (`coverage_pct` / `accuracy_pct`), markdown-qa results, `partial` artifacts if any, and the consolidated open questions (especially constants-vs-entity calls). Then point at the next step in the chain:
- **Build the backlog** → `/replicate-legacy <module>` (it consumes this folder; no re-analysis).
- Or, for a single PBI referencing this module, `/implement-pbi` research reads these artifacts directly.

## Notes
- **One primary human gate** (inventory scope confirm, step 1) plus the escalation-only gate at the coverage cap (step 3). The authoring gates live downstream in `/replicate-legacy`.
- Everything between the gates runs automatically; the artifacts land **uncommitted** for human review like all pipeline output.
- This command replaces the retired single-shot `sp3-legacy-explorer` pass with herman-documenter's phased methodology: persistent artifacts, inventory-driven completeness, code-backed claims, and a coverage-validation gate.
