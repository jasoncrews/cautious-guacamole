# StarterPack V3 Agent Orchestration

How this pack's AI agents, commands, and skills fit together — from a raw idea to reviewed, tested code on a feature branch. Everything under `.claude/` is git-tracked and shipped with the repo, so on pull you have the whole pipeline.

> **SP3 reference source.** Canonical conventions and code examples live in the **`StarterPack3`** repo (Azure DevOps project **`EA-StarterPack3`**, https://dev.azure.com/iuait/EA-StarterPack3) — fetch real files from it via the Azure DevOps MCP rather than assuming. Example paths below use the `StarterPack3.*` prefix and reference modules (e.g. `TrainingProvider`, `HvacIssue`); **your app is a `dotnet new StarterPack3` instance with its own project prefix** — discover it from your local `.slnx`/top-level projects and substitute. The pipeline *structure* (evaluator-optimizer loops, research fan-out, guardrails) is repo-agnostic.

> **New here? Read this first, then jump to [End-to-end flow](#end-to-end-flow).** You drive the pipeline with **slash commands**; the commands orchestrate the **agents**.

---

## Principles (true for every agent)

- **Evaluator–optimizer loops.** Authoring and planning each pair an *optimizer* (drafts) with an *evaluator* (reviews). Drafts don't become real work items / code until the evaluator approves. Max **2 revision cycles**, then it escalates to you.
- **Subagents can't spawn subagents.** Only the main loop (you, via a command) can fan out agents. Research fan-out and the review loops are **orchestrator-owned**. Each command notes a *resilience fallback*: if an optimizer can't invoke its reviewer itself, the command drives the loop instead.
- **Humans own two things, always:** the **New→Approved** state transition (no agent ever approves a work item) and **committing/pushing** (agents leave changes uncommitted on a branch for review).
- **Tasks are a sprint-planning fallback; effort is always human-set.** Authoring (`/new-pbi`, `/decompose`, `/refine-pbi`) is **PBI-terminal** — it never creates Tasks. `/implement-pbi` creates child Tasks from the approved plan **only if** the team hasn't already broken the PBI down in sprint planning. No agent ever sets story points / hours / activity, at any level.
- **Least privilege.** Each agent's `tools:` list is the minimum it needs. Among agents, only the BA *writes* to Azure DevOps; the `/implement-pbi` **orchestrator** (main loop) additionally creates child Tasks at implement time. Only the implementer can `Edit`/`Bash`; research agents are read-only.
- **Durable artifacts, not chat.** Plans and backlog docs land in `Data/Plans/` (tracked, PR-reviewed); learnings land in per-agent `agent-memory/`.

---

## Commands (your entry points)

| Command | Purpose | Args | Drives | Human gates |
|---|---|---|---|---|
| **`/new-pbi`** | Interactively author **one** new PBI to the Markdown standard — the command interviews you for the user story + acceptance criteria, then creates it in **New** (optionally under an existing Feature/Epic). | `[idea/description] [parent-id] [project]` | *(orchestrator interview)* → `azure-devops-business-analyst` ↔ `plan-reviewer` | brief confirm + pre-creation approval |
| **`/decompose`** | Break an Epic/Feature/large requirement into a parent-linked **Epic→Feature→PBI** backlog (created in **New**). | `<epic-or-feature-id \| description> [project]` | `azure-devops-business-analyst` ↔ `plan-reviewer` | scope confirm + pre-creation approval |
| **`/refine-pbi`** | Bring one existing non-conformant PBI up to the Markdown standard **in place** (text-only; never changes state/children). | `<work-item-id> [project]` | `azure-devops-business-analyst` (+ optional `plan-reviewer`) | pre-update approval |
| **`/implement-pbi`** | Build one **Approved** PBI end-to-end: research → plan → child Tasks (fallback) → TDD backend → Rivet UI, on a feature branch, **uncommitted**. | `<work-item-id> [project]` | research agents → planner ↔ plan-reviewer → (orchestrator creates Tasks) → tdd-implementer → ui-builder | target confirm + pre-implementation approval |
| **`/replicate-legacy`** | Plan a legacy module as a Feature + increasing-complexity PBIs (StarterPack V3 CRUD guide). | `<module-name> <legacy-repo-path>` | `sp3-legacy-explorer` → `azure-devops-business-analyst` ↔ `plan-reviewer` | same as authoring |
| **`/curate-tool-candidates`** | Weekly triage of inline helper code agents logged, to decide what to extract into a tool/skill. | — | none (main loop) | you decide promote/keep/drop |

---

## Agents

Ten agents in four groups. All are `model: opus`, `memory: project` (each keeps a `MEMORY.md` index in its own `agent-memory/<name>/` dir).

### Authoring / backlog (the `/decompose`, `/refine-pbi`, `/replicate-legacy` engine)

| Agent | Role | Key tools | Notes |
|---|---|---|---|
| **`azure-devops-business-analyst`** | **Optimizer.** Drafts the Plan Artifact (Epic/Feature/PBI tree), then on approval creates + parent-links work items in **New**. | file (Glob/Grep/Read/Write), `Skill`, `Task`, `PowerShell`, **ADO read+write** (`wit_create_work_item`, `wit_update_work_item(s_batch)`, `wit_work_items_link`, `wit_get_*`, `search_workitem`, `work_*` iterations) | **The only agent that writes to Azure DevOps.** PBI-terminal; renders PBIs via the Markdown skill; foundation-first vertical-slice decomposition. |
| **`plan-reviewer`** | **Evaluator.** Sanity + SP3-consistency + **hierarchy-integrity / decomposition** review; returns a structured verdict. | file tools, `WebFetch/WebSearch`, **ADO read-only**, `repo_*`, `search_code`, `wiki_*` | No write tools by design — it reviews, never edits the plan or the board. |

### Research (read-only leaves — `/implement-pbi` step 1.5 fan-out)

| Agent | Role | Key tools |
|---|---|---|
| **`sp3-analog-scout`** | Rank the closest module to mirror; return the exact file slice (entity→DbContext→CQRS→controller→DTOs→Refit→BFF→Razor→tests). | `Glob, Grep, Read, Write` |
| **`sp3-dependency-mapper`** | What the PBI touches: shared entities/DbContext/permissions/migrations + FK/nav deps; related/duplicate ADO items. | file tools + **ADO read** (`search_workitem`, `wit_query_by_wiql`, `wit_get_*`) |
| **`sp3-standards-rivet-researcher`** | Distill SP3 conventions + **verified Rivet** components/CSS into a cheat-sheet (UI PBIs only). | `Read, Glob, Grep, Write, WebFetch` + `search_wiki`/`wiki_get_page_content` + **Rivet MCP** |
| **`sp3-legacy-explorer`** | Walk a legacy repo path; summarize pages/entities/logic/workflows; map to a StarterPack3 analog. | `Glob, Grep, Read, Write` |

> Each research agent tags every claim `verified | from-memory(date) | inferred` and writes findings only to its **own** memory dir (no cross-agent write races).

### Implementation (the `/implement-pbi` build engine)

| Agent | Role | Key tools | Notes |
|---|---|---|---|
| **`sp3-implementation-planner`** | **Optimizer.** Investigates real files, drafts a layered TDD plan, runs the reviewer loop, saves the plan to `Data/Plans/`. | file tools, `Skill`, `Task`, `PowerShell`, **ADO read**, `repo_*`, `search_code`, `wiki_*`, **Rivet MCP** | No code, no migrations, no ADO writes. |
| **`sp3-implementation-plan-reviewer`** | **Evaluator.** Verifies the plan against the codebase + SP3/Rivet, checks test-first coverage of every AC; structured verdict. | file tools, `WebFetch/Search`, **ADO read**, `repo_*`, `search_code`, `wiki_*`, Rivet MCP (read) | Never rewrites the plan or writes code. |
| **`sp3-tdd-implementer`** | **Leaf.** Creates `feature/pbi-<id>`, red→green→refactor across **backend/BFF** layers until backend ACs pass. Leaves changes **uncommitted**. | `Glob, Grep, Read, Write, Edit, PowerShell, Bash, Skill`, **ADO read**, `repo_*`, `search_code` | Only agent with `Edit`/`Bash`. Defers `.razor` UI. Never commits/pushes/PRs or touches ADO. |
| **`sp3-rivet-ui-builder`** | **Leaf.** Builds the Blazor `.razor` UI to convention with verified Rivet components; verifies via `dotnet build` + manual checklist. Uncommitted, same branch. | `Glob, Grep, Read, Write, Edit, PowerShell`, `wit_get_work_item`, **Rivet MCP** | Runs after the backend is green. No commits/ADO writes. |

---

## End-to-end flow

```
                          ┌─────────────────────────────────────────────────────────────┐
  IDEA / EPIC / FEATURE   │                      AUTHORING                                │
  design handoff ───────► │  /decompose   BA(optimizer) ⇄ plan-reviewer(evaluator)        │
  one PBI idea ─────────► │  /new-pbi  interview → BA ⇄ plan-reviewer(evaluator)          │
  legacy module ──────────►  /replicate-legacy → sp3-legacy-explorer → BA ⇄ plan-reviewer │
                          │     │  (gate 1: scope)        (loop ≤2)                        │
                          │     ▼  (gate 2: approve creation)                              │
                          │  Epic→Feature→PBI created in NEW, parent-linked                │
                          │  backlog doc → Data/Plans/feature-<id>-<slug>-backlog.md       │
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
  │  1  confirm target (gate 1)                                                             │
  │  1.5 RESEARCH fan-out (parallel, orchestrator-owned):                                   │
  │       analog-scout │ dependency-mapper │ standards-rivet* │ legacy-explorer*            │
  │       → digest → Data/Plans/pbi-<id>-<slug>-research.md                                 │
  │  2  sp3-implementation-planner(optimizer) ⇄ sp3-implementation-plan-reviewer  (loop ≤2) │
  │       → plan → Data/Plans/pbi-<id>-<slug>.md                                            │
  │  3  HUMAN approves the plan (gate 2)                                                    │
  │  3.5 orchestrator creates child Tasks from the plan — ONLY if none exist (New, no effort)│
  │  4  sp3-tdd-implementer → feature/pbi-<id>: red→green→refactor backend/BFF (UNCOMMITTED) │
  │  5  sp3-rivet-ui-builder → .razor UI on same branch (if plan has ui_tasks)              │
  │  6  report: AC→test matrix, files, build/test output                                    │
  └───────────────────────────────────────┬──────────────────────────────────────────────┘
                                           │
                              ┌────────────▼────────────┐
                              │ HUMAN reviews & commits  │  ◄── agents never commit/push/PR
                              │   the branch, opens PR   │
                              └─────────────────────────┘
        (* standards-rivet runs only for UI PBIs; legacy-explorer only when a legacy path is in scope)
```

**In words:**
1. **Author the backlog.** `/decompose` (or `/replicate-legacy`) turns an idea/feature/legacy module into an Epic→Feature→PBI tree. The BA drafts, `plan-reviewer` checks decomposition + conventions, and on your approval the items are created in **New**, parent-linked, with a backlog doc in `Data/Plans/`. `/new-pbi` is the front-door for a single fresh PBI — it interviews you for the user story + acceptance criteria, then hands the brief to the BA; `/refine-pbi` is the side-door to fix one existing PBI in place.
2. **A human approves a PBI** (New→Approved). Nothing implements until this happens.
3. **Implement it.** `/implement-pbi` grounds the work with a parallel research fan-out (digest saved), the planner+reviewer produce a TDD plan you approve. If the PBI has no child Tasks yet, the orchestrator creates them from the plan (New, no effort) — otherwise it respects the team's sprint-planning breakdown. Then the tdd-implementer builds the backend test-first and the ui-builder builds the Razor UI — all on `feature/pbi-<id>`, **left uncommitted**.
4. **A human reviews, commits, and opens the PR.** The plan + backlog doc travel with the branch; UI still needs manual in-browser verification.

---

## Artifacts & shared assets

| Path | What | Who writes it |
|---|---|---|
| `StarterPack3.Application.Api/Data/Plans/feature-<id>-<slug>-backlog.md` (or `<slug>-backlog.md` for a `pbis-only` / `/new-pbi` ask) | Authoring/backlog guidance (the *why* of a decomposition) | BA, on creation |
| `StarterPack3.Application.Api/Data/Plans/pbi-<id>-<slug>-research.md` | Research digest (analog/deps/standards/legacy) | `/implement-pbi` orchestrator |
| `StarterPack3.Application.Api/Data/Plans/pbi-<id>-<slug>.md` | Per-PBI TDD implementation plan | planner |
| `.claude/agent-memory/<agent>/MEMORY.md` + files | Per-agent durable learnings (conventions, gotchas) | each agent |
| `.claude/agents/tool-candidates.jsonl` | Logged inline helpers awaiting extraction | any agent; curated via `/curate-tool-candidates` |

> `Data/Plans/` is **tracked and never auto-deleted** — plans are reviewed in the PR next to the code.

**Skills** (deterministic helpers, invoked via the `Skill` tool):
- **`render-plan-artifact-markdown`** — renders Plan Artifact PBIs to Azure DevOps **Markdown** (the team default; set field `format: "Markdown"`).
- **`render-plan-artifact`** — the HTML variant, retained only for non-team/external consumers.

**Templates** (`.claude/templates/`):
- **`pbi-template.md`** — the canonical PBI shape (Overview, User Story, New Entities, Gherkin, plain AC bullets).
- **`feature-epic-template.md`** — the Feature/Epic shapes + the foundation-first decomposition heuristic.

---

## Guardrails cheat-sheet

- **Human-only New→Approved**, at every level. Agents create in **New**.
- **Authoring never creates Tasks.** `/implement-pbi` creates child Tasks from the approved plan **only if** sprint planning hasn't already — created Tasks are **New** with **no effort fields**. No agent ever sets story points / hours / activity, anywhere.
- **Agents never commit, push, open PRs, or change work-item state** beyond their documented writes (only the BA writes to ADO, and only to create/link/refine).
- **PBIs are always Markdown**; Epics/Features are small hand-authored Markdown bodies. On *updates* to existing items, avoid raw `< > & "` (ADO strips/escapes them) and use `wit_update_work_items_batch` to persist the Markdown format flag.
- **Hierarchy links** use `wit_work_items_link` `type:"parent"` (parent created before child) — never `wit_add_child_work_items` (it can't set AC/tags/rendered body).
- **Two human gates per command** (see the table); everything between runs automatically.

---

## Quick reference

- **Got something bigger than one PBI (a feature/epic/multi-PBI ask)?** → `/decompose` *(breadth: split + sequence a tree)*
- **Got a single PBI and want to be interviewed into a good one?** → `/new-pbi [idea] [parent-id]` *(depth: one item, done right)*
- **A specific existing PBI is messy?** → `/refine-pbi <id>`
- **Porting an old app module?** → `/replicate-legacy <module> <path>`
- **A PBI is Approved and ready to build?** → `/implement-pbi <id>`
- **Friday tooling housekeeping?** → `/curate-tool-candidates`

Each agent's full prompt lives in `.claude/agents/<name>.md`; each command in `.claude/commands/<name>.md`. This document is the map; those files are the territory.
