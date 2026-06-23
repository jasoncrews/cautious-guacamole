<div align="center">

# ⚡ Agent Pack

### Automated Engineering Ecosystem

A high-density mission control for autonomous software agents.
Decompose complex ideas, implement with TDD rigor, and scale production at machine velocity.

![System Status](https://img.shields.io/badge/SYSTEM-OPERATIONAL-00e5b0?style=for-the-badge&labelColor=0d1117)
![Version](https://img.shields.io/badge/VERSION-2.4.0--STABLE-00e5b0?style=for-the-badge&labelColor=0d1117)
![Test Coverage](https://img.shields.io/badge/TEST_COVERAGE-98.2%25-00e5b0?style=for-the-badge&labelColor=0d1117)
![Velocity](https://img.shields.io/badge/VELOCITY-42_pts-00e5b0?style=for-the-badge&labelColor=0d1117)

</div>

---

## 🔄 Lifecycle Workflow

The pack moves every idea through a deterministic five-stage pipeline before a single line of code is committed.

**01 — Idea Formulation**
Translate high-level product vision into structured natural language prompts for the initial analysis phase.

**02 — Autonomous Decomposition**
The Scout and BA agents recursively break down requirements into atomic user stories and technical specifications.

**03 — Backlog Refinement**
Tasks are prioritized and queued in the Pack Engine, waiting for the Implementer agents to begin execution.

**04 — Human Approval**
A non-blocking validation gate ensuring the proposed roadmap aligns with the architectural intent of the lead developer.

**05 — TDD Implementation** ✅
Code is written following a strict "Test-First" paradigm, ensuring 100% logic coverage before merging to the main branch.

---

## 🤖 Active Agents

| Agent | Status | Role | Current Task |
|---|---|---|---|
| **The BA (Business Analyst)** | 🟢 NOMINAL | Orchestrates requirement gathering and ensures technical alignment with business goals | Analyzing V3 Schema |
| **The Scout** | 🟢 NOMINAL | Proactively scans the codebase for technical debt and identifies optimization opportunities | Scanning Dependency Graph |
| **The Planner** | 🟢 NOMINAL | Sequences tasks for maximum efficiency based on agent availability and system priorities | Optimizing Sprint 12 |
| **TDD Implementer** | 🟢 NOMINAL | Synthesizes robust, test-backed code in isolated sandboxes before integration | Refactoring Auth Middleware |

---

## 📋 Commands (Your Entry Points)

| Command | What it does | Human Gates |
|---|---|---|
| `/new-pbi [idea] [parent-id]` | Interviews you for the user story + acceptance criteria, then authors one PBI in New | confirm brief → approve creation |
| `/decompose <id \| description>` | Breaks a large requirement into a parent-linked Epic→Feature→PBI backlog, created in New | confirm scope → approve creation |
| `/refine-pbi <work-item-id>` | Brings one existing off-standard PBI up to the Markdown standard in place | approve update |
| `/implement-pbi <work-item-id>` | Builds one Approved PBI end-to-end: research → plan → Tasks → TDD backend → Rivet UI | confirm target → approve plan |
| `/replicate-legacy <module> <path>` | Explores a legacy module and plans it as a Feature + increasing-complexity PBIs | same as authoring |
| `/curate-tool-candidates` | Triages the inline-helper code agents have logged to decide what to extract into a reusable tool/skill | you decide promote/keep/drop |

---

## 🗂️ What's in the Pack

```
.claude/
├─ ORCHESTRATION.md          # Full map: agents, commands, flow diagram, guardrails
├─ README.md                 # The pack's own quick tour
├─ agents/                   # 10 agent prompts (+ tool-candidates.jsonl log)
├─ commands/                 # 6 slash commands (your entry points)
├─ skills/                   # render-plan-artifact-markdown + render-plan-artifact (HTML)
├─ templates/                # pbi-template.md, feature-epic-template.md
└─ agent-memory/<agent>/     # Per-agent learning stores, indexed by MEMORY.md (ship empty)
```

> 📖 The authoritative map is `.claude/ORCHESTRATION.md` — read it for the per-agent tool lists, the flow diagram, and the resilience fallbacks.
>
> ---
>
> ## 🚀 Quick Start
>
> **1. Add the pack**
> Copy the `.claude/` folder into the root of your StarterPack V3 repo. It's git-tracked and travels with the repo.
>
> **2. Connect MCP servers**
> At minimum the Azure DevOps MCP must be registered as `Azure Devops`.
>
> **3. Set your project**
> Replace `<your-azure-devops-project>` with your team's project, or pass `[project]` per invocation.
>
> **4. Drive it**
> ```bash
> /decompose 104871              # break Feature 104871 into an Epic→Feature→PBI backlog
> /new-pbi "bulk-import providers from CSV" 104871
> /implement-pbi 104812          # after a human moves the PBI New → Approved
> ```
>
> ---
>
> ## 🔒 Guardrails (Non-Negotiable)
>
> - **Human-only New → Approved.** Agents create work items in `New`; only a human approves and only a human starts implementation.
> - - **Agents never commit, push, or open PRs.** Implementation lands on `feature/pbi-<id>`, uncommitted, for human review.
>   - - **Authoring is PBI-terminal; effort is always human-set.** `/decompose` and `/refine-pbi` never create Tasks.
>     - - **Subagents can't spawn subagents.** Review loops and research fan-out are orchestrator-owned.
>       - - **Least privilege.** Each agent's `tools:` list is the minimum it needs.
>        
>         - ---
>
> ## ⚙️ Prerequisites
>
> - **Azure DevOps MCP server** — registered under the exact server name `Azure Devops` so tools resolve as `mcp__Azure_Devops__*`
> - - **PowerShell on PATH** — the `render-plan-artifact*` skills shell out to a `.ps1` renderer
>   - - **Rivet design-system MCP** *(optional, name `rivet-design-system`)* — used to confirm Rivet components for UI PBIs
>     - - **.NET build** — the implementation agents build with `dotnet build <YourApp>.slnx`
>      
>       - ---
>
> <div align="center">

**Pack Health: EXCELLENT** &nbsp;|&nbsp; Test Coverage: 98.2% &nbsp;|&nbsp; Velocity: 42 pts

*Nothing becomes a real work item or committed code until a human says go.*

</div>
