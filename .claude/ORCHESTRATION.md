# StarterPack V3 Agent Orchestration

How this pack's AI agents, commands, and skills fit together — from a raw idea to reviewed, tested code on a feature branch. Everything under `.claude/` is git-tracked and shipped with the repo, so on pull you have the whole pipeline.

> **SP3 reference source.** Canonical conventions and code examples live in the **`StarterPack3`** repo (Azure DevOps project **`EA-StarterPack3`**, https://dev.azure.com/iuait/EA-StarterPack3) — fetch real files from it via the Azure DevOps MCP rather than assuming. Example paths below use the `StarterPack3.*` prefix and reference modules (e.g. `TrainingProvider`, `HvacIssue`); **your app is a `dotnet new StarterPack3` instance with its own project prefix** — discover it from your local `.slnx`/top-level projects and substitute. The pipeline *structure* (evaluator-optimizer loops, research fan-out, guardrails) is repo-agnostic.

> **New here? Read this first, then jump to [End-to-end flow](#end-to-end-flow).** You drive the pipeline with **slash commands**; the commands orchestrate the **agents**.

---

## Principles (true for every agent)

- **Evaluator–optimizer loops.** Authoring and planning each pair an *optimizer* (drafts) with an *evaluator* (reviews). Drafts don't become real work items / code until the evaluator approves. The **authoring** loop caps at **2 revision cycles**; the **implementation planning** loop caps **by tier** (S=1 / M=2 / L,XL=3). Either way it escalates to you when the cap is hit.
- **Problem sizing shapes the pipeline.** The orchestrator assesses each PBI's complexity tier (S/M/L/XL) at the start of `/implement-pbi`, presents the assessment, and you confirm or override. The confirmed tier governs which research agents run, the plan-review cap, whether the hardener runs, and its kill-rate target. Small problems skip most of the pipeline; large ones use the full stack.
- **Spec-first.** `sp3-spec-validator` runs before research, every time. A blocking spec gap stops the pipeline until you resolve it — no planner should have to guess intent.
- **Subagents can't spawn subagents — or talk to the user.** Only the main loop (you, via a command) can fan out agents or pause for a human answer. Research fan-out, the review loops, and **every human gate** are therefore **orchestrator-owned**: optimizers are invoked in explicit modes (draft / revise / create) and each invocation returns to the command, which runs the reviewer and gates creation.
- **Humans own two things, always:** the **New→Approved** state transition (no agent ever approves a work item) and **committing/pushing** (agents leave changes uncommitted on a branch for review).
- **Tasks are a sprint-planning fallback; effort is always human-set.** Authoring (`/new-pbi`, `/decompose`, `/refine-pbi`, `/replicate-legacy`) is **PBI-terminal** — it never creates Tasks. `/implement-pbi` creates child Tasks from the approved plan **only if** the team hasn't already broken the PBI down in sprint planning. No agent ever sets story points / hours / activity, at any level.
- **Least privilege.** Each agent's `tools:` list is the minimum it needs. Among agents, only the BA *writes* to Azure DevOps; the main-loop **orchestrators** additionally make their commands' documented writes (`/implement-pbi` child Tasks, `/refine-pbi` in-place text updates, `/sprint-review` comments). Only the implementer, refactorer, hardener, and ui-builder can `Edit` and carry `PowerShell` (git/build); research and review agents are read-only.
- **Durable artifacts, not chat.** Plans and backlog docs land in `.claude/plans/` (tracked, PR-reviewed); learnings land in per-agent `agent-memory/`.

---

## Commands (your entry points)

| Command | Purpose | Args | Drives | Human gates |
|---|---|---|---|---|
| **`/new-pbi`** | Interactively author **one** new PBI to the Markdown standard — the command interviews you for the user story + acceptance criteria, then creates it in **New** (optionally under an existing Feature/Epic). | `[idea/description] [parent-id] [project]` | *(orchestrator interview)* → `azure-devops-business-analyst` ↔ `plan-reviewer` | brief confirm + pre-creation approval |
| **`/decompose`** | Break an Epic/Feature/large requirement into a parent-linked **Epic→Feature→PBI** backlog (created in **New**). | `<epic-or-feature-id \| description> [project]` | `azure-devops-business-analyst` ↔ `plan-reviewer` | scope confirm + pre-creation approval |
| **`/refine-pbi`** | Bring one existing non-conformant PBI up to the Markdown standard **in place** (text-only; never changes state/children). | `<work-item-id> [project]` | *(main loop — uses the BA's schema/template + render skill itself, no BA spawn)* + optional `plan-reviewer` | pre-update approval |
| **`/implement-pbi`** | Build one **Approved** PBI end-to-end: size → spec-validate → research → plan → child Tasks (fallback) → TDD backend → refactor → Rivet UI → harden, on a feature branch, **uncommitted**. | `<work-item-id> [project]` | spec-validator → research agents → planner ↔ plan-reviewer → (orchestrator creates Tasks) → tdd-implementer → refactorer → ui-builder → hardener | tier confirm + pre-implementation approval (+ XL revision visibility) |
| **`/analyze-legacy`** | Phased legacy-module analysis (herman-documenter methodology): inventory → 5 parallel lenses → coverage validation → synthesis → tracked artifacts in `.claude/plans/legacy-<slug>/`. Analysis only; head of the legacy chain. | `<module-name> <legacy-repo-path>` | `sp3-legacy-analyst` ×phases → `sp3-legacy-coverage-validator` (≤2 fix cycles) | scope confirm (+ coverage-cap escalation) |
| **`/replicate-legacy`** | Author a legacy module as a Feature + increasing-complexity PBIs **from the `/analyze-legacy` artifacts** (StarterPack V3 CRUD guide). | `<module-name> [legacy-repo-path]` | consumes `analysis-digest.md` → `azure-devops-business-analyst` ↔ `plan-reviewer` | same as authoring |
| **`/curate-tool-candidates`** | Weekly triage of inline helper code agents logged, to decide what to extract into a tool/skill. | — | none (main loop) | you decide promote/keep/drop |
| **`/retro`** | Post-run retrospective on a long multi-agent run: harvest durable learnings and turn the systemic ones into reviewed edits to the agents/commands/templates/memory. Uncommitted. | `[run-descriptor \| work-item-id \| transcript-path]` | (orchestrator harvests) → `retro-analyst` (verifies/classifies) → (orchestrator applies) | pick-findings + approve-edits |
| **`/sprint-review`** | Turn a sprint-review transcript into backlog actions — author new PBIs, refine existing ones, record decisions, flag plan impacts. Everything created in **New**. | `<transcript-path \| notes> [project] [iteration]` | `sprint-review-analyst` (extract/classify) → `/new-pbi`, `/refine-pbi`, `/decompose` engines (BA ↔ plan-reviewer) | confirm action-list + approve writes |
| **`/optimize-agents`** | Proactively audit + optimize the pack's **own definitions — agents, commands, and templates** (least-privilege, single-source MCP-fetch, doc-vs-code drift, efficiency-by-tier, robustness) and run a cross-agent alignment check — uncommitted. | `[name \| glob \| "all"]` | (orchestrator) → `agent-auditor` ×N **parallel** (audits) → (orchestrator applies + aligns) | review-findings + approve-edits |

---

## Agents

Seventeen agents in eight groups, all `memory: project` (each keeps a `MEMORY.md` index in its own `agent-memory/<name>/` dir). **Models are tiered:** the read-only research / extraction / structured-verification leaves (`sp3-spec-validator`, `sp3-analog-scout`, `sp3-dependency-mapper`, `sp3-standards-rivet-researcher`, `sp3-legacy-analyst`, `sp3-legacy-coverage-validator`, `retro-analyst`, `sprint-review-analyst`, `agent-auditor`) run on **`sonnet`** — they read, summarize, and tag, and their output is re-verified downstream; the generative / high-stakes agents (`azure-devops-business-analyst`, `plan-reviewer`, `sp3-implementation-planner`, `sp3-implementation-plan-reviewer`, `sp3-tdd-implementer`, `sp3-refactorer`, `sp3-rivet-ui-builder`, `sp3-hardener`) run on **`opus`**. There is **no** local `conventions.md`; each agent opens with an **SP3 reference source** blockquote and fetches real conventions from the `StarterPack3` repo (`EA-StarterPack3`) via the Azure DevOps MCP at run start rather than carrying a frozen copy.

### Authoring / backlog (the `/decompose`, `/refine-pbi`, `/replicate-legacy` engine)

| Agent | Role | Key tools | Notes |
|---|---|---|---|
| **`azure-devops-business-analyst`** | **Optimizer.** Invoked by the commands in three modes — **draft** / **revise** (return a Plan Artifact, no writes) and **create** (after reviewer approval + the human gate, creates + parent-links work items in **New**). | file (Glob/Grep/Read/Write), `Skill`, `PowerShell` (solely to run the render skill's script), **ADO read+write** (`wit_create_work_item`, `wit_update_work_item(s_batch)`, `wit_work_items_link`, `wit_add_work_item_comment`, `wit_get_work_item`, `wit_get_work_items_batch_by_ids`, `wit_get_work_item_type`, `wit_query_by_wiql`, `search_workitem`, `core_list_*`, `work_*` iterations) | **The only agent that writes to Azure DevOps.** PBI-terminal; renders PBIs via the Markdown skill; foundation-first vertical-slice decomposition. The commands run the `plan-reviewer` loop between its invocations. |
| **`plan-reviewer`** | **Evaluator.** Sanity + SP3-consistency + **hierarchy-integrity / decomposition** review; returns a structured verdict. | file tools, **ADO read-only** (`wit_get_*`, `wit_query_by_wiql`, `search_workitem`), `repo_get_file_content`/`repo_list_directory`, `search_code`, `search_wiki`/`wiki_get_page_content` | No write tools by design — it reviews, never edits the plan or the board. |

### Pre-flight (the `/implement-pbi` spec gate)

| Agent | Role | Key tools | Notes |
|---|---|---|---|
| **`sp3-spec-validator`** | **Pre-flight leaf.** Validates every AC bullet and Gherkin scenario for observability, completeness, non-contradiction, and edge-case coverage before research begins. Returns `ready` or `needs_clarification` with a gap list. | `Read, Write`, **ADO read** (`wit_get_work_item`) | Runs every time, all tiers. Blocking gaps stop the pipeline; advisory gaps are forwarded to the planner. Never modifies ADO or spawns agents. |

### Research (read-only leaves — `/implement-pbi` step 2 fan-out)

| Agent | Role | Key tools |
|---|---|---|
| **`sp3-analog-scout`** | Rank the closest module to mirror; return the exact file slice (entity→DbContext→CQRS→controller→DTOs→Refit→BFF→Razor→tests). | `Glob, Grep, Read, Write` + **ADO read** (`search_code`, `repo_get_file_content`, `repo_list_directory`) |
| **`sp3-dependency-mapper`** | What the PBI touches: shared entities/DbContext/permissions/migrations + FK/nav deps; related/duplicate ADO items. | file tools + **ADO read** (`search_code`, `repo_get_file_content`, `repo_list_directory`, `search_workitem`, `wit_query_by_wiql`, `wit_get_*`) |
| **`sp3-standards-rivet-researcher`** | Distill SP3 conventions + **verified Rivet** components/CSS into a cheat-sheet (UI PBIs only). | `Read, Glob, Grep, Write, WebFetch` + **ADO read** (`search_code`, `repo_get_file_content`, `repo_list_directory`, `search_wiki`, `wiki_get_page_content`) + **Rivet MCP** |
| **`sp3-legacy-analyst`** | Legacy slice for one PBI (`scoped-recon`): summarize pages/entities/logic/workflows, map to a StarterPack3 analog. **Artifact-first** — reads a persisted `/analyze-legacy` digest when one exists. *(Also the engine of the `/analyze-legacy` chain — see below.)* | `Glob, Grep, Read, Write, Edit` + **ADO read** (`search_code`, `repo_get_file_content`, `repo_list_directory`) |

> Each research agent tags every claim `verified | from-memory(date) | inferred` and writes findings only to its **own** memory dir (no cross-agent write races).

### Legacy analysis (the `/analyze-legacy` engine)

| Agent | Role | Key tools |
|---|---|---|
| **`sp3-legacy-analyst`** | **Phased analyst.** Runs ONE phase per invocation — `inventory` → (`data-model` `roles` `process` `business-rules` `ui-flows` in parallel) → `synthesis` — each writing one Markdown artifact to `.claude/plans/legacy-<slug>/`. Also serves the `/implement-pbi` research `scoped-recon` fallback (above). | `Glob, Grep, Read, Write, Edit` + **ADO read** (`search_code`, `repo_get_file_content`, `repo_list_directory`) |
| **`sp3-legacy-coverage-validator`** | **Evaluator.** After the six analysis phases, verifies the artifacts are complete + accurate against the legacy source; writes `coverage-report.md` and returns a JSON verdict (`complete` / `gaps_found`) the orchestrator acts on — re-dispatching targeted analyst fix runs (≤2 cycles). | `Glob, Grep, Read, Write` |

> Output feeds `/replicate-legacy` (backlog authoring) and `/implement-pbi` (research). Deterministic markdown hygiene runs via the **`markdown-qa`** skill (no agent).

### Implementation (the `/implement-pbi` build engine)

| Agent | Role | Key tools | Notes |
|---|---|---|---|
| **`sp3-implementation-planner`** | **Optimizer.** Investigates real files, drafts a layered TDD plan, revises on each orchestrator-passed verdict, saves the plan to `.claude/plans/`. | file tools, **ADO read** (`wit_get_*`, `search_workitem`), `repo_get_file_content`/`repo_list_directory`, `search_code`, **Rivet MCP** | No code, no migrations, no ADO writes; saves the plan via `Write`. |
| **`sp3-implementation-plan-reviewer`** | **Evaluator.** Verifies the plan against the codebase + SP3/Rivet, checks test-first coverage of every AC; structured verdict. | file tools, **ADO read** (`wit_get_work_item`), `repo_get_file_content`/`repo_list_directory`, `search_code`, Rivet MCP (read) | Never rewrites the plan or writes code. |
| **`sp3-tdd-implementer`** | **Leaf.** Creates `feature/pbi-<id>`, red→green→refactor (**micro-level** only) across **backend/BFF** layers until backend ACs pass. Leaves changes **uncommitted**. | `Glob, Grep, Read, Write, Edit, PowerShell`, **ADO read** (`wit_get_work_item`), `repo_*`, `search_code` | Defers `.razor` UI. Micro-refactor only (naming, private-method extraction within a file) — structural cleanup is `sp3-refactorer`'s job. Never commits/pushes/PRs or touches ADO. |
| **`sp3-refactorer`** | **Leaf.** Structural cleanup pass after the implementer: duplication reduction, method-size enforcement, constants extraction, property-based edge-case tests — tests green throughout. | `Glob, Grep, Read, Write, Edit, PowerShell`, `repo_*`, `search_code` | Does not change API contracts. Does not build UI. Single pass, no loop. Scopes work from the plan file (no ADO work-item read; repo-read for convention checks). |
| **`sp3-rivet-ui-builder`** | **Leaf.** Builds the Blazor `.razor` UI to convention with verified Rivet components; verifies via `dotnet build` + manual checklist. Uncommitted, same branch. | `Glob, Grep, Read, Write, Edit, PowerShell`, `wit_get_work_item`, **ADO repo read** (`search_code`, `repo_get_file_content`, `repo_list_directory`), **Rivet MCP** | Runs after the backend is green. No commits/ADO writes. |
| **`sp3-hardener`** | **Leaf.** Runs Stryker.NET mutation testing scoped to PBI-touched files; patches the weakest tests to raise the kill rate to the tier target; max 2 Stryker rounds. | `Glob, Grep, Read, Write, Edit, PowerShell`, `repo_*`, `search_code` | Skipped for S-tier PBIs. Kill-rate targets: M=70%, L=80%, XL=85%. Scopes work from the plan file (no ADO work-item read; repo-read for convention checks). |

### Retrospective (the `/retro` engine)

| Agent | Role | Key tools |
|---|---|---|
| **`retro-analyst`** | **Evaluator.** Verifies candidate retro findings against the current `.claude/` definitions and live code; classifies each as confirmed / stale / misattributed / one-off with priority + suggested edit. Read-only leaf — the `/retro` orchestrator applies approved edits. | `Glob, Grep, Read, Write` + **ADO read** (`search_code`, `repo_get_file_content`, `repo_list_directory`) |

### Intake / triage (the `/sprint-review` engine)

| Agent | Role | Key tools |
|---|---|---|
| **`sprint-review-analyst`** | **Extractor.** Reads a sprint-review transcript and returns a classified, transcript-cited action list (new-pbi / new-feature / refine-existing / bug / plan-impact / comment / parking-lot), matching change/comment items to existing ADO work items. Read-only leaf — never creates/edits work items or writes the digest. | `Read, Glob, Grep, Write` + **ADO read** (`search_workitem`, `wit_query_by_wiql`, `wit_get_*`) |

### Pipeline maintenance (the `/optimize-agents` engine)

| Agent | Role | Key tools |
|---|---|---|
| **`agent-auditor`** | **Evaluator.** Audits one `.claude/` definition — agent, command, or template — against the optimization checklist (least-privilege, single-source MCP-fetch discipline, doc-vs-code drift, efficiency-by-tier, robustness, coherence/guardrails; tool/model dimensions apply to agents only) and returns structured findings with exact before/after edits. Read-only leaf — verifies SP3 claims against the `StarterPack3` repo via MCP; the `/optimize-agents` orchestrator applies edits at a human gate and runs the cross-agent alignment check. | `Glob, Grep, Read, Write` (own memory) + **ADO read** (`search_code`, `repo_get_file_content`, `repo_list_directory`) |

---

## End-to-end flow

```
                          ┌─────────────────────────────────────────────────────────────┐
  IDEA / EPIC / FEATURE   │                      AUTHORING                                │
  design handoff ───────► │  /decompose   BA(optimizer) ⇄ plan-reviewer(evaluator)        │
  one PBI idea ─────────► │  /new-pbi  interview → BA ⇄ plan-reviewer(evaluator)          │
  legacy module ──────────►  /analyze-legacy → /replicate-legacy → BA ⇄ plan-reviewer     │
  sprint transcript ──────►  /sprint-review → sprint-review-analyst → BA ⇄ plan-reviewer  │
                          │     │  (gate 1: scope/action-list)  (loop ≤2)                  │
                          │     ▼  (gate 2: approve creation)                              │
                          │  Epic→Feature→PBI created in NEW, parent-linked                │
                          │  backlog doc → .claude/plans/feature-<id>-<slug>-backlog.md    │
                          └───────────────┬─────────────────────────────────────────────┘
                                          │
                       (existing PBI off-standard? → /refine-pbi: in-place, text-only)
                                          │
                              ┌───────────▼───────────┐
                              │   HUMAN approves PBI   │   ◄── only a human does New→Approved
                              │      (New → Approved)  │
                              └───────────┬───────────┘
                                          │
  ┌───────────────────────────────────────▼──────────────────────────────────────────────┐
  │                                 IMPLEMENTATION  (/implement-pbi)                        │
  │  1   confirm target + SIZE the problem tier S/M/L/XL (gate 1)                            │
  │  1.5 SPEC-VALIDATE: sp3-spec-validator → ready | needs_clarification (blocking → stop)   │
  │  2   RESEARCH fan-out (parallel, orchestrator-owned, gated by tier):                     │
  │       analog-scout │ dependency-mapper │ standards-rivet* │ legacy-analyst*             │
  │       → digest → .claude/plans/pbi-<id>-<slug>-research.md                              │
  │  3   sp3-implementation-planner ⇄ sp3-implementation-plan-reviewer (cap by tier 1/2/3)  │
  │       → plan → .claude/plans/pbi-<id>-<slug>.md                                         │
  │  4   HUMAN approves the plan (gate 2)                                                    │
  │  4.5 orchestrator creates child Tasks from the plan — ONLY if none exist (New, no effort)│
  │  5   sp3-tdd-implementer → feature/pbi-<id>: red→green→refactor backend/BFF (UNCOMMITTED)│
  │  6   sp3-refactorer → structural cleanup pass (duplication, size, constants, edge cases) │
  │  7   sp3-rivet-ui-builder → .razor UI on same branch (if plan has ui_tasks)             │
  │  8   sp3-hardener → Stryker mutation testing [M/L/XL only, max 2 rounds]                 │
  │  9   report: AC→test matrix, tier, files, build/test output                             │
  └───────────────────────────────────────┬──────────────────────────────────────────────┘
                                           │
                              ┌────────────▼────────────┐
                              │ HUMAN reviews & commits  │  ◄── agents never commit/push/PR
                              │   the branch, opens PR   │
                              └─────────────────────────┘
        (* standards-rivet runs only for UI PBIs; legacy-analyst only when a legacy path is in scope — artifact-first, else scoped-recon)
```

**In words:**
1. **Author the backlog.** `/decompose` (or, for a legacy module, the `/analyze-legacy` → `/replicate-legacy` chain) turns an idea/feature/legacy module into an Epic→Feature→PBI tree. The BA drafts, `plan-reviewer` checks decomposition + conventions, and on your approval the items are created in **New**, parent-linked, with a backlog doc in `.claude/plans/`. `/new-pbi` is the front-door for a single fresh PBI — it interviews you for the user story + acceptance criteria, then hands the brief to the BA; `/refine-pbi` is the side-door to fix one existing PBI in place. `/sprint-review` is the fourth intake: `sprint-review-analyst` turns a sprint-review transcript into a classified, cited action list, which the orchestrator dispatches to those same authoring engines — new PBIs/bugs in **New**, in-place refinements of existing PBIs, recorded decisions, and `plan-impact` flags for a `/implement-pbi` re-plan.
2. **A human approves a PBI** (New→Approved). Nothing implements until this happens.
3. **Implement it.** `/implement-pbi` assesses the problem tier (S/M/L/XL), you confirm. The spec-validator checks every AC and Gherkin scenario for testability before research begins. A parallel research fan-out grounds the work (digest saved); the planner+reviewer produce a TDD plan you approve (cycle cap scales with tier). If the PBI has no child Tasks yet, the orchestrator creates them from the plan (New, no effort) — otherwise it respects the team's sprint-planning breakdown. Then the tdd-implementer builds the backend test-first, the refactorer runs a structural cleanup pass, the ui-builder builds the Razor UI, and the hardener verifies test quality via mutation testing (M+ tiers) — all on `feature/pbi-<id>`, **left uncommitted**.
4. **A human reviews, commits, and opens the PR.** The plan + backlog doc travel with the branch; UI still needs manual in-browser verification.

---

## Artifacts & shared assets

| Path | What | Who writes it |
|---|---|---|
| `.claude/plans/feature-<id>-<slug>-backlog.md` (or `<slug>-backlog.md` for a `pbis-only` / `/new-pbi` ask) | Authoring/backlog guidance (the *why* of a decomposition) | BA, on creation |
| `.claude/plans/pbi-<id>-<slug>-research.md` | Research digest (analog/deps/standards/legacy) + confirmed tier + spec-validator advisory notes | `/implement-pbi` orchestrator |
| `.claude/plans/pbi-<id>-<slug>.md` | Per-PBI TDD implementation plan | planner |
| `.claude/plans/sprint-review-<YYYY-MM-DD>-<slug>.md` | Sprint-review digest (classified action list + what was created/refined/commented + plan-impacts + parking-lot) | `/sprint-review` orchestrator |
| `.claude/retros/retro-<YYYY-MM-DD>-<slug>.md` | Retro artifact (actioned findings + diffs, deferred one-offs, preserved strengths) | `/retro` orchestrator |
| `.claude/audits/optimize-agents-<YYYY-MM-DD>.md` | Agent-optimization sweep report (findings + diffs + alignment results + deferred items) | `/optimize-agents` orchestrator |
| `.claude/agent-memory/<agent>/MEMORY.md` + files | Per-agent durable learnings (conventions, gotchas) | each agent |
| `.claude/agents/tool-candidates.jsonl` | Logged inline helpers awaiting extraction | any agent; curated via `/curate-tool-candidates` |

> `.claude/plans/` is **tracked and never auto-deleted** — plans ship with the pack and are reviewed in the PR alongside the change.

**Skills** (invoked via the `Skill` tool):

*Pipeline helpers (deterministic, ADO-specific):*
- **`render-plan-artifact-markdown`** — renders Plan Artifact PBIs to Azure DevOps **Markdown** (the team default; set field `format: "Markdown"`).
- **`render-plan-artifact`** — the HTML variant, retained only for non-team/external consumers; `disable-model-invocation: true`, so it is user-invoked only and intentionally outside the pipeline.
- **`markdown-qa`** — deterministic Node normalizer + cross-file link checker for a folder of generated Markdown (used by `/analyze-legacy`).

*Engineering skills (general-purpose, ported from [mattpocock/skills](https://github.com/mattpocock/skills)):*
- **`diagnosing-bugs`** — diagnosis loop for hard bugs / perf regressions: build a tight, red-capable feedback loop *before* hypothesising → reproduce + minimise → rank hypotheses → instrument → fix + regression test → cleanup. Fills the pack's debugging gap; composes with `sp3-tdd-implementer`. Ships a PowerShell + bash HITL helper.
- **`codebase-design`** — shared vocabulary for **deep modules** (module, interface, depth, seam, adapter, leverage, locality) + the deletion test. Reference for `sp3-refactorer` / `sp3-implementation-planner` and the rubric `/optimize-agents` can measure against. Discloses `DEEPENING.md` and `DESIGN-IT-TWICE.md`.
- **`writing-great-skills`** — user-invoked reference for authoring/editing skills (predictability, completion criteria, progressive disclosure, leading words, failure modes). The design manual for `/optimize-agents` and `/retro`. Discloses `GLOSSARY.md`.
- **`resolving-merge-conflicts`** — resolve an in-progress merge/rebase, run `dotnet build`/`test`/`format`, then **stop at the finish line** (stage, hand the commit/`rebase --continue` to the human — adapted to the pack's never-commit rule).
- **`handoff`** — user-invoked: compact the current conversation into a handoff doc (in OS temp) so a fresh session can continue.
- **`git-guardrails`** — manages the active PreToolUse hook that blocks dangerous git commands (see guardrails cheat-sheet).

**Templates** (`.claude/templates/`):
- **`pbi-template.md`** — the canonical PBI shape (Overview, User Story, New Entities, Gherkin, plain AC bullets).
- **`feature-epic-template.md`** — the Feature/Epic shapes + the foundation-first decomposition heuristic.

---

## Guardrails cheat-sheet

- **Human-only New→Approved**, at every level. Agents create in **New**.
- **Authoring never creates Tasks.** `/implement-pbi` creates child Tasks from the approved plan **only if** sprint planning hasn't already — created Tasks are **New** with **no effort fields**. No agent ever sets story points / hours / activity, anywhere.
- **Agents never commit, push, open PRs, or change work-item state** beyond their documented writes (only the BA writes to ADO, and only to create/link/refine). This is now **mechanically enforced** by the `block-dangerous-git` PreToolUse hook (wired in `settings.json`), which blocks `git push`, `reset --hard`, `clean -f[d]`, `branch -D`, and `checkout .`/`restore .` from the Bash/PowerShell tools — the human runs these from their own terminal. Manage it via the `git-guardrails` skill.
- **PBIs are always Markdown**; Epics/Features are small hand-authored Markdown bodies. On *updates* to existing items, avoid raw `< > & "` (ADO strips/escapes them) and use `wit_update_work_items_batch` to persist the Markdown format flag.
- **Hierarchy links** use `wit_work_items_link` `type:"parent"` (parent created before child) — never `wit_add_child_work_items` (it can't set AC/tags/rendered body).
- **Two human gates per command** (see the table); everything between runs automatically. (`/implement-pbi` adds a spec-validator pause only when a blocking gap is found, and XL-tier plan-revision visibility.)
- **Spec-first + tier-scaled.** `sp3-spec-validator` runs before research every time; the confirmed S/M/L/XL tier governs which research agents run, the plan-review cap (S=1/M=2/L,XL=3), and whether the hardener runs (S skips it). Hardener is capped at **2 Stryker rounds**.

---

## Quick reference

- **Got something bigger than one PBI (a feature/epic/multi-PBI ask)?** → `/decompose` *(breadth: split + sequence a tree)*
- **Got a single PBI and want to be interviewed into a good one?** → `/new-pbi [idea] [parent-id]` *(depth: one item, done right)*
- **A specific existing PBI is messy?** → `/refine-pbi <id>`
- **Porting an old app module?** → `/analyze-legacy <module> <path>` (phased analysis) → `/replicate-legacy <module>` (backlog)
- **A PBI is Approved and ready to build?** → `/implement-pbi <id>`
- **Friday tooling housekeeping?** → `/curate-tool-candidates`
- **Just finished a long multi-agent run?** → `/retro` *(harvest learnings → pipeline improvements)*
- **Sprint review just happened?** → `/sprint-review <transcript>` *(transcript → backlog actions)*
- **Want to tune the agents themselves?** → `/optimize-agents [all | glob | name]` *(proactive least-privilege + drift + alignment sweep)*

Each agent's full prompt lives in `.claude/agents/<name>.md`; each command in `.claude/commands/<name>.md`. This document is the map; those files are the territory.
