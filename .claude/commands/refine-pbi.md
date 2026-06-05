---
description: Refine an existing Azure DevOps PBI up to the team's Markdown PBI standard, in place, without changing its state
argument-hint: <work-item-id> [project]
---

Refine Azure DevOps work item **$ARGUMENTS** so it matches the team's PBI standard in `.claude/templates/pbi-template.md`. This is **in-place editing of an existing PBI** — not creating a new one. If no id was supplied, ask for it. Project defaults to `<your-azure-devops-project>`.

You run this in the main loop (so you can call `plan-reviewer` directly if you want a quality pass — subagents can't spawn subagents). Keep the user in the loop at the single approval gate.

## Hard rules (non-negotiable)

- **Preserve the state.** NEVER change `System.State`. Refinement is text-only. A human is the only one who moves a PBI New → Approved, and you must never regress an Active/Committed/Done item. Just improve the Description + AcceptanceCriteria fields.
- **Preserve every fact.** Migrate ALL existing content into the new structure — do not drop information. If something seems wrong or redundant and you'd remove it, surface it for the human instead of deleting silently.
- **Do not invent requirements.** Derive Gherkin scenarios and plain AC bullets from the behavior the PBI already describes. For anything genuinely missing or ambiguous, add it to open questions and ASK — never fabricate scope.
- **No tasks, no effort, no child changes.** Do not create/modify child work items or set story points / hours.
- **Markdown.** The refined PBI is Markdown (team standard), with the format flag set correctly.

## Steps

### 1. Fetch & read
`wit_get_work_item` (expand `all`). Capture: title, `System.Description`, `Microsoft.VSTS.Common.AcceptanceCriteria`, `multilineFieldsFormat`, `System.State`, tags, parent, and child links. Note whether the description is HTML or Markdown.

### 2. Gap report (show the user)
Compare the current PBI to the template and list what's missing/non-conformant, e.g.:
- Format is HTML rather than Markdown
- No `## Overview` / `## User Story`
- No `## Acceptance Scenarios (Gherkin)`
- AcceptanceCriteria field empty / contains prose instead of plain testable bullets
- Entities described in prose rather than `## New Entities` code blocks; not declared `: EntityBase`; missing navigation properties
- AC bullets duplicated in the Description

If `System.State` is `Done`/`Closed`/`Removed`, warn that refining a completed item is usually unnecessary and **confirm** before continuing.

### 3. Draft the refined PBI (preserve + restructure + fill gaps)
Build a Plan Artifact (one PBI) per the `azure-devops-business-analyst` schema, **carrying over all existing content**:
- Existing intro/prose → `overview` + `user_story` + `developer_context_and_goals`.
- Inline entity definitions → `entities` as code blocks: declare `<Name> : EntityBase` (audit fields CreatedBy/CreatedDateTime/ModifiedBy/ModifiedDateTime inherited — do NOT relist), list every entity-specific field, and add the **navigation properties** for any relationships (FK id + nav property + inverse collections). Keep any domain action fields (e.g. ActionDate/ActionUsername) the entity already has as normal fields.
- API / UI / file lists → `file_targets` and/or `additional_sections`.
- Derive `gherkin_scenarios` (Feature/Scenario/Given/When/Then) and plain `acceptance_criteria` bullets from the described behavior. Each AC bullet should mirror a scenario and vice-versa.
- Anything you cannot derive without guessing → `open_questions`.

### 4. Render
Call the `render-plan-artifact-markdown` skill with the Plan Artifact → `description_markdown` + `acceptance_criteria_markdown`.

### 5. (Optional) quality pass
For anything beyond a pure reformat, invoke `plan-reviewer` via the Task tool with the draft and apply its blocker/issue findings. Skip for a trivial reformat with no new/derived requirements.

### 6. Approval gate (one human gate)
Show the user: the gap report, the proposed **new Description** (rendered Markdown) and **new AcceptanceCriteria** bullets, the open questions, and anything that would be dropped or materially reworded. Resolve blocking open questions with the human first. **Explicitly ask permission to update the work item.** Do not proceed without a yes.

### 7. Update in place
On approval, `wit_update_work_item`:
- `System.Description` = `description_markdown`, with `format: "Markdown"`.
- `Microsoft.VSTS.Common.AcceptanceCriteria` = `acceptance_criteria_markdown`, with `format: "Markdown"`.
- If a field comes back still flagged `html`, fix it with the two-patch-op call (`/multilineFieldsFormat/...` + `/fields/...`) per the render skill's SKILL.md.
- Do NOT modify `System.State`, child work items, effort fields, or (unless asked) tags.

### 8. Verify
Re-fetch and confirm: both fields `multilineFieldsFormat == "markdown"`; AcceptanceCriteria holds the plain bullets; the Description does NOT duplicate the plain AC bullet list (Gherkin scenarios + entity code blocks in the Description are expected); `System.State` unchanged. Fix and re-verify if any check fails.

### 9. Report
Summarize before → after (format flipped, sections added, AC field populated, entities upgraded), list any still-open questions for the human, and link the work item. Note that the state was left untouched.

## Notes
- One human gate only: the pre-update approval (step 6).
- This complements `azure-devops-business-analyst` (which authors *new* PBIs to the same template) — same conventions, same render skill, applied to an existing item.
- If the PBI is large/bundles multiple modules (e.g. two entities), refine it as one well-structured PBI; do NOT split it into new work items here — flag a suggested split in your report for the human to decide.
