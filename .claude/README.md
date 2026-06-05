# StarterPack V3 Azure DevOps Agent Pack

A reusable Claude Code pack that takes a requirement all the way from a raw idea to **reviewed, tested code on a feature branch** — authoring a well-structured Azure DevOps backlog, then planning and TDD-implementing each PBI against **IU StarterPack V3** conventions (styled with the **Rivet** design system). Drop the `.claude/` folder into the root of any StarterPack V3 repo.

> **SP3 reference source.** The canonical StarterPack V3 reference implementation is the **`StarterPack3`** repo in Azure DevOps project **`EA-StarterPack3`** (https://dev.azure.com/iuait/EA-StarterPack3). The agents are told to fetch real SP3 conventions and code examples from that repo via the Azure DevOps MCP rather than assuming. Example paths in these files use the canonical `StarterPack3.*` project prefix and reference modules (e.g. `TrainingProvider`, `HvacIssue`) — **your app is a `dotnet new StarterPack3` instance with its own project prefix**, so discover it from your local `.slnx`/top-level projects and substitute. The pipeline *structure* is repo-agnostic.

**📖 The full map is [`ORCHESTRATION.md`](ORCHESTRATION.md)** — every agent, command, skill, the end-to-end flow diagram, and the guardrails. Start there. This README is the quick tour.

## The flow in one line

```
idea          → /decompose ───────┐
single PBI    → /new-pbi ─────────┤→ backlog in NEW → human Approves → /implement-pbi → research → plan → TDD code on a feature branch (uncommitted) → human reviews, commits, opens PR
legacy module → /replicate-legacy ─┘
```

Two evaluator–optimizer loops do the heavy lifting (an *optimizer* drafts, an *evaluator* reviews, max 2 cycles): one for **authoring** the backlog, one for **planning** the implementation. Nothing becomes a real work item or committed code until a human approves.

## Commands (your entry points)

| Command | Purpose |
|---|---|
| `/new-pbi [idea] [parent-id]` | Interview you into **one** well-formed PBI, created in **New**. |
| `/decompose <epic-or-feature-id \| description>` | Break an Epic/Feature/large requirement into a parent-linked **Epic→Feature→PBI** backlog (New). |
| `/refine-pbi <work-item-id>` | Bring one existing off-standard PBI up to the Markdown standard **in place** (text-only). |
| `/implement-pbi <work-item-id>` | Build one **Approved** PBI end-to-end: research → plan → child Tasks (fallback) → TDD backend → Rivet UI, on a feature branch, **uncommitted**. |
| `/replicate-legacy <module> <legacy-repo-path>` | Plan a legacy module as a Feature + increasing-complexity PBIs (StarterPack V3 CRUD guide). |
| `/curate-tool-candidates` | Triage inline helper code agents logged, to decide what to extract into a tool/skill. |

> The authoring commands default their Azure DevOps project to a placeholder (`<your-azure-devops-project>`) — set it to your team's project or pass `[project]` per invocation.

## Agents (ten, in four groups)

- **Authoring / backlog** — `azure-devops-business-analyst` (optimizer; the only agent that writes to Azure DevOps) ↔ `plan-reviewer` (evaluator).
- **Research** (read-only leaves, fanned out by `/implement-pbi`) — `sp3-analog-scout`, `sp3-dependency-mapper`, `sp3-standards-rivet-researcher`, `sp3-legacy-explorer`.
- **Implementation** — `sp3-implementation-planner` (optimizer) ↔ `sp3-implementation-plan-reviewer` (evaluator) → `sp3-tdd-implementer` (backend/BFF, test-first) → `sp3-rivet-ui-builder` (Blazor/Rivet UI).

Each agent's full prompt is in `agents/<name>.md` and opens with an **SP3 reference source** note pointing at the `StarterPack3` repo via MCP. Each keeps a per-repo learning store in `agent-memory/<name>/` (indexed by `MEMORY.md`). **These ship empty** — every agent records durable facts about *your* project as it works.

## Non-negotiable guardrails

- **Human-only `New → Approved`.** Agents create work items in **New**; only a human approves.
- **Agents never commit, push, or open PRs.** Implementation lands on `feature/pbi-<id>`, **uncommitted**, for human review.
- **Authoring is PBI-terminal; effort is always human-set.** `/decompose` and `/refine-pbi` never create Tasks. `/implement-pbi` creates child Tasks from the approved plan **only if** sprint planning hasn't already — and never sets story points / hours / activity, anywhere.
- **Subagents can't spawn subagents.** The review loops and research fan-out are orchestrator-owned.
- **Least privilege.** Each agent's `tools:` list is the minimum it needs.

## Prerequisites

1. **Azure DevOps MCP server**, registered under the exact server name **`Azure Devops`** so the tools resolve as `mcp__Azure_Devops__*` (the agents' tool allowlists depend on this exact prefix). Configure it in your `~/.claude/mcp.json` (or project equivalent) and enable it. Point it at your organization; the agents reference the `EA-StarterPack3` project for canonical examples.
2. **PowerShell** on PATH — the `render-plan-artifact*` skills shell out to a `.ps1` renderer.
3. **Rivet design-system MCP** (optional, name `rivet-design-system`) — used to look up correct Rivet components, utility classes, and design tokens for UI PBIs. Without it, the agents flag Rivet lookups as open items instead of guessing class names.
4. **.NET build** — the implementation agents build with `dotnet build <YourApp>.slnx` (the reference app uses `StarterPack3.slnx`, .NET 10). Adjust to your solution.

## Skills & templates

- **`render-plan-artifact-markdown`** — renders Plan Artifact PBIs to Azure DevOps **Markdown** (the team default). **`render-plan-artifact`** — the HTML variant, for non-team/external consumers.
- **`templates/pbi-template.md`** — the canonical PBI shape. **`templates/feature-epic-template.md`** — Feature/Epic shapes + the foundation-first decomposition heuristic.

## Paths & portability

All paths inside these files are **repo-relative** (`.claude/...`), so the pack works in any clone on any machine; skills use `${CLAUDE_SKILL_DIR}` for their bundled scripts. SP3-specific *content* (project prefix, example modules, your Azure DevOps project) is yours to point at your own repo — the agent-memory and tool-candidates log start empty and accumulate per-repo.
