# StarterPack V3 Agent Pack

The **Agent Pack** is a drop-in Claude Code configuration (`.claude/`) that turns a requirement into a well-structured Azure DevOps backlog and then into **reviewed, tested code on a feature branch** — all under human approval gates. It is tailored to **IU StarterPack V3** (.NET, multi-tenant, Blazor) apps styled with the **Rivet** design system.

You drive it with **slash commands**; the commands orchestrate a team of **agents** that draft, review, research, plan, and implement. Drop the `.claude/` folder into the root of any StarterPack V3 repo and the commands light up.

> **SP3 reference source.** The canonical StarterPack V3 reference implementation is the **`StarterPack3`** repo in Azure DevOps project **`EA-StarterPack3`** (https://dev.azure.com/iuait/EA-StarterPack3). The agents fetch real conventions and code examples from that repo via the Azure DevOps MCP rather than assuming. Example paths use the canonical `StarterPack3.*` prefix and reference modules (e.g. `TrainingProvider`, `HvacIssue`); **your app is a `dotnet new StarterPack3` instance with its own project prefix**, so the agents discover it from your local `.slnx`/top-level projects and substitute.

---

## What's in the pack

```
.claude/
├─ ORCHESTRATION.md          # the full map: agents, commands, flow diagram, guardrails
├─ README.md                 # the pack's own quick tour
├─ agents/                   # 10 agent prompts (+ tool-candidates.jsonl log)
├─ commands/                 # 6 slash commands (your entry points)
├─ skills/                   # render-plan-artifact-markdown (default) + render-plan-artifact (HTML)
├─ templates/                # pbi-template.md, feature-epic-template.md
└─ agent-memory/<agent>/     # per-agent learning stores, indexed by MEMORY.md (ship empty)
```

**📖 The authoritative map is [`.claude/ORCHESTRATION.md`](.claude/ORCHESTRATION.md)** — read it for the per-agent tool lists, the flow diagram, and the resilience fallbacks. This file is the front-door overview.

---

## How it works

```
idea          → /decompose ───────┐
single PBI    → /new-pbi ─────────┤→ backlog created in NEW → human Approves a PBI → /implement-pbi
legacy module → /replicate-legacy ─┘                                                      │
                                                                                          ▼
                          research fan-out → plan → (child Tasks, fallback) → TDD backend → Rivet UI
                                                                                          │
                                                          all on feature/pbi-<id>, UNCOMMITTED
                                                                                          ▼
                                              human reviews the branch, commits, opens the PR
```

The pack runs **two evaluator–optimizer loops** — an *optimizer* drafts, an *evaluator* reviews, the optimizer revises (max 2 cycles), then it escalates to you:

- **Authoring loop** — `azure-devops-business-analyst` drafts a Plan Artifact (Epic/Feature/PBI tree); `plan-reviewer` checks decomposition + StarterPack V3/Rivet conventions; on your approval the items are created in **New**, parent-linked.
- **Planning loop** — `sp3-implementation-planner` drafts a layered, test-first plan grounded in your real code; `sp3-implementation-plan-reviewer` verifies it covers every acceptance criterion before any code is written.

Nothing becomes a real work item or committed code until a human says go.

---

## Commands (your entry points)

| Command | What it does | Human gates |
|---|---|---|
| `/new-pbi [idea] [parent-id]` | Interviews you for the user story + acceptance criteria, then authors **one** PBI in **New** (optionally under a Feature/Epic). | confirm brief → approve creation |
| `/decompose <epic-or-feature-id \| description>` | Breaks a large requirement into a parent-linked **Epic→Feature→PBI** backlog, created in **New**. | confirm scope → approve creation |
| `/refine-pbi <work-item-id>` | Brings one existing off-standard PBI up to the Markdown standard **in place** (text only — never changes state/children). | approve update |
| `/implement-pbi <work-item-id>` | Builds one **Approved** PBI end-to-end: research → plan → child Tasks (only if none exist) → TDD backend → Rivet UI, on `feature/pbi-<id>`, **uncommitted**. | confirm target → approve plan |
| `/replicate-legacy <module> <legacy-repo-path>` | Explores a legacy module and plans it as a Feature + increasing-complexity PBIs (StarterPack V3 CRUD guide). | same as authoring |
| `/curate-tool-candidates` | Triages the inline-helper code agents have logged, to decide what to extract into a reusable tool/skill. | you decide promote/keep/drop |

---

## Agents (ten, in four groups)

| Agent | Group | Role | Writes to ADO? | Edits code? |
|---|---|---|---|---|
| `azure-devops-business-analyst` | Authoring | **Optimizer.** Drafts the Epic/Feature/PBI tree; on approval creates + parent-links work items in **New**. PBI-terminal (never creates Tasks). | ✅ (the only one) | — |
| `plan-reviewer` | Authoring | **Evaluator.** Sanity + decomposition + SP3/Rivet consistency review; structured verdict. | — (read-only) | — |
| `sp3-analog-scout` | Research | Ranks the closest existing module to mirror; returns the exact file slice to copy. | — | — |
| `sp3-dependency-mapper` | Research | Maps what the PBI touches (entities, DbContext, permissions, migrations, related work items). | — (read) | — |
| `sp3-standards-rivet-researcher` | Research | Distills SP3 conventions + **verified** Rivet components/CSS into a cheat-sheet (UI PBIs). | — | — |
| `sp3-legacy-explorer` | Research | Summarizes a legacy module and maps it to the closest SP3 analog. | — | — |
| `sp3-implementation-planner` | Implementation | **Optimizer.** Investigates real files, drafts a layered TDD plan, runs the reviewer loop, saves the plan. | — (read) | — |
| `sp3-implementation-plan-reviewer` | Implementation | **Evaluator.** Verifies the plan against the codebase + SP3/Rivet and test-first coverage of every AC. | — (read) | — |
| `sp3-tdd-implementer` | Implementation | **Leaf.** Creates the branch; red→green→refactor across backend/BFF until backend ACs pass. Leaves changes **uncommitted**. | — (read) | ✅ |
| `sp3-rivet-ui-builder` | Implementation | **Leaf.** Builds the Blazor `.razor` UI to convention with verified Rivet components, after the backend is green. | — | ✅ |

Research and review agents are **read-only leaves**; only the BA writes to Azure DevOps, and only `sp3-tdd-implementer`/`sp3-rivet-ui-builder` edit code — and never commit. Each agent's `.md` opens with an **SP3 reference source** note pointing at the `StarterPack3` repo via MCP.

### Skills & templates

- **`render-plan-artifact-markdown`** — deterministic PowerShell renderer: Plan Artifact → Azure DevOps **Markdown** (the team default), keeping acceptance criteria in the dedicated field, never the Description. **`render-plan-artifact`** is the HTML variant for non-team/external consumers.
- **`templates/pbi-template.md`** — the canonical PBI shape (Overview, User Story, New Entities, Gherkin, plain AC bullets). **`templates/feature-epic-template.md`** — Feature/Epic shapes + the foundation-first decomposition heuristic.

---

## Install & use

1. **Add the pack.** Copy the `.claude/` folder into the root of your StarterPack V3 repo (or clone this repo as a starting point). It's all git-tracked, so it travels with the repo.
2. **Connect the MCP servers** (see Prerequisites). At minimum the Azure DevOps MCP must be registered as **`Azure Devops`**.
3. **Set your project.** The authoring commands default their Azure DevOps project to the placeholder `<your-azure-devops-project>` — replace it with your team's project, or pass `[project]` per invocation.
4. **Drive it with a command.** For example:

   ```
   /decompose 104871                 # break Feature 104871 into an Epic→Feature→PBI backlog
   /new-pbi "let admins bulk-import providers from CSV" 104871
   /implement-pbi 104812             # after a human moves the PBI New → Approved
   ```

   The command runs the relevant loop, pauses at each human gate, and (for `/implement-pbi`) leaves the built branch uncommitted for your review.

### Prerequisites

1. **Azure DevOps MCP server**, registered under the exact server name **`Azure Devops`** so tools resolve as `mcp__Azure_Devops__*` (the agents' tool allowlists depend on this exact prefix). Configure it in `~/.claude/mcp.json` (or project equivalent) and enable it. The agents reference the `EA-StarterPack3` project for canonical examples.
2. **PowerShell** on PATH — the `render-plan-artifact*` skills shell out to a `.ps1` renderer.
3. **Rivet design-system MCP** (optional, name `rivet-design-system`) — used to confirm Rivet components, utility classes, and design tokens for UI PBIs. Without it, agents flag Rivet lookups as open items instead of guessing.
4. **.NET build** — the implementation agents build with `dotnet build <YourApp>.slnx` (the reference app uses `StarterPack3.slnx`, .NET 10). Adjust to your solution.

---

## Guardrails (non-negotiable)

- **Human-only `New → Approved`.** Agents create work items in **New**; only a human approves and only a human starts implementation.
- **Agents never commit, push, or open PRs.** Implementation lands on `feature/pbi-<id>`, **uncommitted**, for human review.
- **Authoring is PBI-terminal; effort is always human-set.** `/decompose` and `/refine-pbi` never create Tasks. `/implement-pbi` creates child Tasks from the approved plan **only if** sprint planning hasn't already — and no agent ever sets story points / hours / activity, anywhere.
- **Subagents can't spawn subagents.** The review loops and research fan-out are orchestrator-owned.
- **Least privilege.** Each agent's `tools:` list is the minimum it needs.

## Conventions baked in

- **Authorization** is policy-based (`[Authorize(Policy = "...")]`) against centrally declared policies, not ad-hoc checks.
- **Lookup data** prefers shared-project constants files over DB-backed lookup tables for static data; real entities only for live-source or frequently-churning data.
- **Acceptance criteria** always go in the dedicated `Microsoft.VSTS.Common.AcceptanceCriteria` field, never the Description.
- **PBIs are Markdown** (the team default), rendered via `render-plan-artifact-markdown`.

## Memory & portability

Every agent keeps a per-repo learning store in `.claude/agent-memory/<agent>/`, indexed by that directory's `MEMORY.md`. They **ship empty** — each agent records durable facts about *your* project as it works. The tool-candidates log (`.claude/agents/tool-candidates.jsonl`) also starts empty. All internal paths are **repo-relative** (`.claude/...`) and skills use `${CLAUDE_SKILL_DIR}`, so the pack works in any clone on any machine.
