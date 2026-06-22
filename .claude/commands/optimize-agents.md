---
description: Proactively audit + optimize the pack's own definitions — agents, commands, and templates (least-privilege, single-source MCP-fetch, doc-vs-code drift, efficiency-by-tier, robustness) and run a cross-agent alignment check — uncommitted
argument-hint: '[name | glob | "all"]'
---

Audit and optimize the pipeline's own **definitions** — the agent prompts under `.claude/agents/`, the slash-command orchestration under `.claude/commands/`, and the authoring **templates** under `.claude/templates/` — then verify the whole fleet is internally consistent. This is the **proactive** counterpart to `/retro` (which harvests learnings *after* a run): `/optimize-agents` sweeps these definitions for quality, least-privilege, single-source consistency, and drift — on demand. Templates and commands drift too (a wrong convention in a template fans out to every authored PBI), and nothing else proactively audits them — so a full sweep covers all three surfaces.

Target: **$ARGUMENTS** (a specific definition name/path, a glob, or `all` / empty = every `.claude/agents/*.md` + `.claude/commands/*.md` + `.claude/templates/*.md`).

You are the orchestrator and run this in the **main loop** (so you can fan out the `agent-auditor` subagent — subagents can't spawn subagents). `agent-auditor` only verifies and proposes; **you** apply edits, at a human gate. Keep the user in the loop at **two gates**: review-findings, then approve-edits.

## Hard rules (non-negotiable)

- **Tighten or correct — never loosen.** A refinement may remove an unused tool, fix drift, or de-duplicate; it must **never** weaken a guardrail (a leaf agent's no-commit/no-spawn rules, human-only New→Approved, "create in New", "STOP and report"). If a finding would loosen a guardrail, drop it and flag it to the user.
- **Single source of truth = the StarterPack3 repo via MCP.** This pack carries **no** local `conventions.md`; SP3 conventions are fetched from the `StarterPack3` reference repo (`EA-StarterPack3`) via the Azure DevOps MCP, anchored by each agent's **SP3 reference source** blockquote. Optimizations make agents **fetch/point**, never freeze a drifting copy of convention prose.
- **Verify drift against live code.** A "doc-vs-code" fix is only valid if the StarterPack3 reference repo actually contradicts the prompt — confirm both sides (the auditor uses `search_code`/`repo_get_file_content`) before proposing. Judge the *pattern*, not the literal `StarterPack3.*` prefix (the consuming app has its own).
- **Never commit.** All edits are uncommitted for human review. Prompt edits take effect on the *next* run.
- **Keep the map true.** If an edit changes an agent's tools/model/role, update its `ORCHESTRATION.md` row in the same pass.

## 1. Build the target list (part of gate 1)

Resolve `$ARGUMENTS`:
- empty or `all` → every `.claude/agents/*.md`, plus `.claude/commands/*.md` and `.claude/templates/*.md` (the full pipeline-definition surface).
- a glob (e.g. `sp3-*`) → matching files under `agents/`, `commands/`, or `templates/`.
- a specific name/path → that one file (agent, command, or template).

List the resolved targets and the **reference set** each auditor will check against (`ORCHESTRATION.md`, the baseline `settings.json` + local `settings.local.json` allowlists, and the `StarterPack3` repo via MCP). Confirm the scope with the user before fanning out (cheap; avoids auditing the wrong set).

## 2. Audit (parallel fan-out — orchestrator-owned)

Issue **one `agent-auditor` per target as multiple `Task` calls in a single message** so they run in parallel. Pass each the target file path + the reference-set paths. Each returns a structured findings report (per dimension: least-privilege, single-source MCP-fetch discipline, doc-vs-code accuracy, efficiency-by-tier, robustness, coherence/guardrails), every finding carrying a severity, an exact anchor, live-code evidence, and a concrete before→after edit.

For a **command** or **template** target, tell the auditor it's a non-agent file: it skips the agent-only dimensions (least-privilege `tools`, efficiency-by-tier `model`) and focuses on **doc-vs-code accuracy**, **single-source / MCP-fetch discipline**, and **coherence/guardrails** — a wrong convention frozen in a template (it fans out to every authored PBI) or a stale instruction in a command is exactly the high-blast-radius drift this sweep exists to catch.

Resilience fallback: if you can't invoke `agent-auditor` — the nested-subagent limit, **or** because it was authored earlier in *this* session and the harness only loads agents at startup (so the first `/optimize-agents` right after creating it can't spawn it yet) — do the audit yourself, inline, against the same checklist.

## 3. Assemble the Optimization Report

Aggregate the findings grouped **by target** (agent, command, or template), each with severity (`blocker`/`issue`/`suggestion`), the anchor, the evidence, and the proposed edit. Note cross-cutting patterns (e.g. "three agents hardcode the test stack instead of MCP-fetching it", "two carry a stale `ModifiedBy` reference") — those usually point at a single fix applied fleet-wide.

## 4. Gate 1 — review the findings

Show the user the full report. **Ask which findings to apply** (default-recommend all `blocker`s + `issue`s; `suggestion`s are opt-in). Let them edit, drop, or reclassify. Resolve any intent question here — a change to how an agent behaves is the user's call.

## 5. Gate 2 — approve the edits

For the selected findings, present the **exact edits** (file + before/after). **Explicitly ask permission to apply.** Wait for yes. (You're editing the pipeline's own definitions — don't start without approval.)

## 6. Apply (uncommitted)

On approval:
- **Edit the target files** (agents, commands, or templates) with the approved changes — minimal, precise, matching each file's voice.
- **Update `ORCHESTRATION.md`** rows for any agent whose tools / model / role changed (and the map's prose for any command/template behavior that changed).
- **Allowlist:** a grant that should travel with the pack goes in the tracked baseline `.claude/settings.json` (add the scoped grant; don't broaden beyond it). A purely per-developer grant (e.g. `git push`/`git remote`, a machine-specific MCP server) goes in the git-ignored `settings.local.json`, which merges on top of the baseline. The user owns these permission-machinery edits — propose the exact line and let them apply it.
- **Do NOT** commit, push, or open a PR.

## 7. Alignment check (cross-agent — orchestrator-owned)

After applying, verify the fleet is internally consistent. Run these checks (Grep/Read; report PASS/FAIL with specifics):
1. **Map matches reality** — every `ORCHESTRATION.md` agent row's tools/model/role matches that agent's actual frontmatter + body.
2. **Model tiering holds** — read-only research/extraction/verification leaves run on `sonnet`; generative/code-editing/quality-gate agents on `opus`. Flag any agent off its tier.
3. **Allowlist covers usage** — every MCP tool and git/dotnet command the agents invoke is in the merged allowlist (tracked `settings.json` baseline + per-developer `settings.local.json`), with the shippable grants in the baseline so a fresh clone doesn't prompt (no mid-run prompt gaps); no stale one-off entries reintroduced. If the tracked `settings.json` baseline doesn't exist yet, report **baseline pending (user-owned)** with the missing grants — not FAIL.
4. **Single-source / MCP-fetch intact** — no agent freezes a drifting copy of SP3 convention prose; each carries the **SP3 reference source** blockquote and fetches from StarterPack3 for ground truth. Audit-field names are `UpdatedBy/UpdatedDateTime` everywhere (no `ModifiedBy`); assertion idioms are FluentAssertions (no Shouldly).
5. **No stranded references** — no agent body references a tool it no longer has, or a file/skill/agent that doesn't exist.
6. **Referential integrity** — every agent named in a command exists; every agent has an `agent-memory/<name>/` dir; every agent carries the Memory + Tool-candidate blocks.
7. **Guardrails uniform** — leaf agents still declare no-commit/no-spawn; only the BA writes to ADO; human-only New→Approved is stated where relevant.
8. **Command/template referential integrity** — every agent, skill, template, and artifact path a command or template names exists in the pack (commands and templates strand references too, not just agents).

## 8. Report + artifact

Summarize: which targets changed and why (one line each), any `ORCHESTRATION.md` updates and proposed `settings.json` / `settings.local.json` grants (user-applied), the alignment-check results (each PASS/FAIL), and findings deferred by the user. Save a tracked report to `.claude/audits/optimize-agents-<YYYY-MM-DD>.md` (create the dir if needed): the target list, the actioned findings with diffs, the alignment results, and the deferred items (so the next sweep doesn't re-litigate them). Remind the user everything is **uncommitted** and prompt edits take effect on the next run.

## Notes

- **Two human gates only:** review-findings (step 4) and approve-edits (step 5). Audit + alignment run automatically.
- **`agent-auditor` is the evaluator; you are the optimizer-applier** — mirrors `/retro` and the BA/plan-reviewer split (the read-only agent proposes; only the main loop edits).
- **Proactive vs reactive:** reach for `/optimize-agents` to sweep the fleet for quality/consistency on demand; reach for `/retro` to turn a specific run's learnings into fixes. They share the "propose → human-gate → apply uncommitted" shape.
- **Bias toward fewer, higher-confidence changes.** A sweep that lands real least-privilege + drift fixes beats one that rewords every prompt. When a finding is a judgment call, surface it as a `suggestion` and let the user decide.
