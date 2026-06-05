# StarterPack V3 Azure DevOps Planning Pack

A reusable Claude Code pack for turning requirements into well-structured Azure DevOps backlogs on **IU StarterPack V3** projects (styled with the **Rivet** design system). Drop the `.claude/` folder into the root of any StarterPack repo.

## What's inside

| Component | Type | Role |
|---|---|---|
| `vincent` | agent | **Optimizer / Business Analyst.** Drafts Plan Artifacts (PBIs + tasks), gets them reviewed, and — only after approval — creates and verifies the work items in Azure DevOps. |
| `jules` | agent | **Evaluator / Reviewer.** Reviews Vincent's Plan Artifact against sanity checks and StarterPack V3 / Rivet conventions, returning structured findings. Has **no** write tools by design. |
| `render-plan-artifact` | skill | Deterministic PowerShell renderer that turns a Plan Artifact into Azure DevOps work-item HTML, enforcing that acceptance criteria never leak into the Description field. Called by Vincent in Phase 2. |
| `/replicate-legacy` | command | Plans a legacy-module replication as an incremental PBI sequence under a parent Feature, following the StarterPack V3 CRUD guide. |
| `/curate-tool-candidates` | command | Triages `agents/tool-candidates.jsonl` for the periodic tool-extraction review. |

The two agents form an **evaluator-optimizer loop**: Vincent drafts → Jules reviews → Vincent revises (max 2 cycles) → human-confirmed creation. No work items are created until the plan is approved and you say go.

## How it works

```
You describe a requirement
   → vincent drafts a Plan Artifact (no work items yet)
   → vincent hands it to jules (Task tool)
   → jules returns a structured verdict (approved / needs_revision / rejected)
   → vincent revises until approved, then asks you to confirm
   → vincent creates + verifies PBIs/tasks via the Azure DevOps MCP
```

Invoke it by asking for backlog work, e.g. *"Use vincent to turn this spec into PBIs in Azure DevOps."* Vincent calls Jules automatically.

## Prerequisites

1. **Azure DevOps MCP server**, registered under the exact server name **`Azure Devops`** so the tools resolve as `mcp__Azure_Devops__*` (the agents' tool allowlists depend on this exact prefix). Configure it in your `~/.claude/mcp.json` (or project equivalent) and enable it for the project.
2. **PowerShell** available on PATH — the `render-plan-artifact` skill shells out to `Render-PbiHtml.ps1`.
3. **Rivet design-system MCP** (optional, name `rivet-design-system`) — used to look up correct Rivet components, utility classes, and design tokens for UI PBIs. If it isn't connected, the agents fall back to flagging Rivet lookups as open items instead of guessing class names.

## Conventions baked in

- **Authorization**: policy-based (`[Authorize(Policy = "...")]`) against centrally declared policies, not ad-hoc checks.
- **Lookup data**: shared-project constants files preferred over DB-backed lookup tables for static data; real entities only for live-source or frequently-churning data.
- **Estimation**: handles both `Microsoft.VSTS.Scheduling.StoryPoints` and `Effort` — confirm which your project uses.
- **Acceptance criteria** always go in the dedicated `Microsoft.VSTS.Common.AcceptanceCriteria` field, never in Description.

## Paths

All paths inside these files are **repo-relative** (`.claude/...`), so the pack works in any clone on any machine. The skill uses `${CLAUDE_SKILL_DIR}` for its bundled script. Agent memory and the tool-candidates log start empty and accumulate per-repo.

## Memory

`agent-memory/vincent/` and `agent-memory/jules/` are per-agent learning stores, indexed by each directory's `MEMORY.md`. They ship empty — each agent records durable facts about *your* project as it works.
