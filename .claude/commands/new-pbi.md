---
description: Interactively author a single Azure DevOps PBI to the team's Markdown standard — the command asks clarifying questions to draw out the user story and acceptance criteria, then creates it in New.
argument-hint: [idea/description] [parent-id] [project]
---

Author **one** new Azure DevOps PBI to the team's standard in `.claude/templates/pbi-template.md`, starting from the rough idea in **$ARGUMENTS**. You run the clarifying-question interview yourself, then delegate drafting + review + creation to the `azure-devops-business-analyst` (BA). Project defaults to `<your-azure-devops-project>`.

This is the **depth-on-one-item** front door: it commits to an interview to get a single PBI right. For **breadth** — splitting a larger ask into multiple PBIs, or standing up a Feature/Epic above them — use `/decompose` instead.

You are the orchestrator and run in the main loop. **You own the interview** — when the BA is invoked via the `Task` tool it runs autonomously and cannot stop to ask the user a question and wait for an answer, so the clarifying-question phase has to happen here, in the main loop (the same reason `/decompose` and `/implement-pbi` drive their review loops from the orchestrator). Once you've gathered requirements, hand a complete brief to the BA; the heavy lifting (drafting, the `plan-reviewer` loop, rendering, creation) is the BA's job — don't hand-author the work item yourself.

## Hard rules (non-negotiable)
- **Human-only approval.** The PBI is created in **New**. NEVER set it to Approved or any other state.
- **Optional parent is read-only.** If a parent id is given, author the PBI **under** it — never recreate, edit, or restate it. Fetch it (`wit_get_work_item`) and confirm it's an **Epic** or **Feature**; if it's a PBI, stop and tell the user (refine it via `/refine-pbi`, build it via `/implement-pbi`).
- **No tasks, no effort.** Never create child Tasks or set story points / hours.
- **One PBI.** This command produces a single PBI. If the ask is genuinely multiple capabilities or needs a Feature/Epic above it, stop and point the user to `/decompose`.
- **PBI is Markdown** via the `render-plan-artifact-markdown` skill.
- **Don't fabricate scope.** Anything you can't derive from the conversation goes to `open_questions` and gets asked — never invented.

## 1. Clarify — interview the user (you, the main loop)
Seed from `$ARGUMENTS`: the rough idea, an optional parent id, an optional project. If a parent id was supplied, fetch and verify it now (per the hard rule above) and plan `existing-parent` mode; otherwise plan `pbis-only`.

Then run a short interview to fill every element a standard PBI needs, per `.claude/templates/pbi-template.md`. Use **`AskUserQuestion`** for discrete choices (role/persona, project / area path / iteration, in-scope vs out-of-scope boundaries, priority, tags, audience: worker-`Online.UI` vs `Admin.UI`) and plain conversational prompts for the narrative. Specifically elicit and confirm:
- **User story** — `As a <role>, I want <capability> so that <business value>`.
- **Acceptance criteria** — walk the user through the behavioral expectations and restate them back as plain, testable bullets. Every bullet must map to a Gherkin scenario and vice-versa (the bidirectional coverage the template requires); the BA writes the Gherkin, but confirm the behaviors here.
- **New entities** (if any) — name + the entity-specific fields, so the BA can produce the `## New Entities` block (`: EntityBase`, explicit `<Entity>Id: Guid` PK, FK ids + navigation properties; audit fields inherited, not relisted).
- **Context** — parent id (if any), project / area path / iteration, priority, tags, and the analog module to mirror if the user knows one (e.g. `Movie` for admin CRUD).

Keep it tight — ask only what's missing, don't over-interrogate. Stop once there's enough for an approvable, self-contained PBI.

## 2. Confirm the requirements brief (human gate 1)
Show the assembled brief — user story, scope (in/out), the plain AC bullets, any new entities, the parent (if any), context (project/area/iteration/priority/tags), and any open questions. Confirm with the user before drafting. Resolve blocking open questions now.

## 3. Draft, review, and create (delegate to the BA)
Invoke `azure-devops-business-analyst` via the `Task` tool. Pass it: the confirmed requirements brief, the project, and `decomposition_target.mode` = `existing-parent` (with the verified parent's id + type) or `pbis-only`. The BA will:
- draft a **one-PBI Plan Artifact** (user story, description sections, entities, Gherkin, plain AC) per its schema,
- render it via the `render-plan-artifact-markdown` skill,
- run the `plan-reviewer` loop (max 2 revision cycles) for quality + SP3/convention consistency,
- and, **after the user approves creation (human gate 2)**, create the PBI in **New**, link it under the parent via `wit_work_items_link` (`type: "parent"`) if one was given, verify the create, and write the backlog guidance doc to `StarterPack3.Application.Api/Data/Plans/<slug>-backlog.md`.

At human gate 2, show the rendered **Description** + **AcceptanceCriteria** and the open questions, and explicitly ask permission to create. Do not create without a yes.

Relay the BA's outcome:
- **Approved & created** → show the PBI id, title, link, and parent link (if any). Note it's in **New** awaiting human approval.
- **Failed to converge / rejected** → present the BA's summary + the reviewer findings and stop. Ask how to proceed.

Resilience: if the BA reports it could not invoke `plan-reviewer` itself (nested-subagent limitation), drive the loop yourself — take the BA's draft, invoke `plan-reviewer` via the `Task` tool, hand the verdict back for revision, repeat up to 2 cycles — then return to the BA for creation after the user approves.

## 4. Report
Summarize: the created PBI id + link, the parent link (if any), the backlog doc path, and any open questions for the human. Remind the user that **nothing is Approved** — they review/improve in Azure DevOps and approve; an Approved PBI then flows into `/implement-pbi`.

## Notes
- Two human gates (brief confirmation in step 2, pre-creation approval in step 3) plus the up-front interview.
- Complements `/decompose` (use it for larger asks — Features/Epics or multiple PBIs), `/refine-pbi` (improve an existing PBI in place), and `/implement-pbi` (build an Approved PBI). `/new-pbi` is the front door for a single fresh PBI drawn out of a conversation.
- Produces a full-template PBI (Gherkin + entities + AC) ready for the implementation pipeline.
