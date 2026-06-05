---
name: render-plan-artifact
description: This skill should be used when the azure-devops-business-analyst is in Phase 2 and needs to render Plan Artifact PBIs into Azure DevOps work-item HTML for System.Description and Microsoft.VSTS.Common.AcceptanceCriteria before calling wit_create_work_item. Takes a full Plan Artifact JSON object and returns rendered HTML per PBI.
disable-model-invocation: true
allowed-tools: PowerShell
---

# Render Plan Artifact to Azure DevOps HTML

Invoke the bundled PowerShell script with the Plan Artifact JSON to get rendered HTML for all PBIs in one round-trip:

```powershell
$result = & "${CLAUDE_SKILL_DIR}\scripts\Render-PbiHtml.ps1" -PlanJson $planJson | ConvertFrom-Json
```

The script returns a JSON array. Each element corresponds to one PBI from the input plan, in input order:

```json
[
  {
    "draft_id": "PBI-1",
    "description_html": "...",
    "acceptance_criteria_html": "..."
  }
]
```

Map the result back to PBIs by `draft_id`. Assign `description_html` to `System.Description` and `acceptance_criteria_html` to `Microsoft.VSTS.Common.AcceptanceCriteria` in `wit_create_work_item`. Do NOT splice acceptance criteria into the description — the script enforces this separation but the caller must respect the field assignments.

## Input contract

Source strings in the Plan Artifact are RAW — not pre-escaped. The script HTML-escapes once and wraps code-block content in `<pre><code>…</code></pre>`. Do not pre-escape `&`, `<`, or `>` in the input.

## Invariants the script enforces

- The plain-language acceptance-criteria bullets (`acceptance_criteria`) appear ONLY in `acceptance_criteria_html`, never in `description_html`. Gherkin acceptance *scenarios* are a separate, intentional Description section (`gherkin_scenarios`) and do NOT violate this — they are not the plain bullet list.
- All user-supplied values are HTML-escaped (`&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;`).
- Sections absent or empty in `description_sections` are omitted entirely (no empty headings).
- Code blocks render as `<pre><code>…</code></pre>` with their contents escaped. `gherkin_scenarios` and each entity `definition` render as code blocks.
- `entities` renders under a "New Entities" heading, one labeled `<pre><code>…</code></pre>` per entity (entity `name` in `<em>`, all fields in the block).
- Bullet lists render as `<ul><li>…</li></ul>`, one `<li>` per array element.
- Section order in the description follows: user_story → developer_context_and_goals → entities → file_targets → controller_signatures → sample_request_response → error_response_contract → idempotency → conflict_handling → security → gherkin_scenarios → testing → docs_and_swagger.
