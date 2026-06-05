---
name: render-plan-artifact-markdown
description: This skill should be used when the azure-devops-business-analyst is creating PBIs for the StarterPack3 team and needs to render Plan Artifact PBIs into Azure DevOps work-item MARKDOWN for System.Description and Microsoft.VSTS.Common.AcceptanceCriteria before calling wit_create_work_item. Takes a full Plan Artifact JSON object and returns rendered Markdown per PBI. This is the team's preferred format (matches the gold-standard hand-authored PBIs). For the HTML variant, use render-plan-artifact instead.
disable-model-invocation: true
allowed-tools: PowerShell
---

# Render Plan Artifact to Azure DevOps Markdown

This is the **Markdown** sibling of `render-plan-artifact` (which emits HTML). Both consume the identical Plan Artifact schema, so the only difference between them is the output format — making them suitable for an A/B comparison. Markdown is the StarterPack V3 team default because it is far easier for a human to read and improve in the Azure DevOps editor, and it matches the team's gold-standard hand-authored PBI shape.

Invoke the bundled PowerShell script with the Plan Artifact JSON to get rendered Markdown for all PBIs in one round-trip:

```powershell
$result = & "${CLAUDE_SKILL_DIR}\scripts\Render-PbiMarkdown.ps1" -PlanJson $planJson | ConvertFrom-Json
```

The script returns a JSON array. Each element corresponds to one PBI from the input plan, in input order:

```json
[
  {
    "draft_id": "PBI-1",
    "format": "markdown",
    "description_markdown": "## Overview\n...",
    "acceptance_criteria_markdown": "- ...\n- ..."
  }
]
```

Map the result back to PBIs by `draft_id`. Assign `description_markdown` to `System.Description` and `acceptance_criteria_markdown` to `Microsoft.VSTS.Common.AcceptanceCriteria`.

## CRITICAL: set the field format to Markdown

Azure DevOps stores a per-field format flag. If you write Markdown into a field whose flag is `html`, the Markdown renders as literal text. You MUST set the format to Markdown for both multiline fields, or the body will look broken.

In `wit_create_work_item`, pass `format: "Markdown"` **inside each field object**:

```json
{ "name": "System.Description", "format": "Markdown", "value": "## Overview\n..." }
{ "name": "Microsoft.VSTS.Common.AcceptanceCriteria", "format": "Markdown", "value": "- ..." }
```

After creation, verify `multilineFieldsFormat.System.Description == "markdown"` and `...AcceptanceCriteria == "markdown"`. If either came back `html`, fix with `wit_update_work_item` using two patch ops in one call:

```json
[
  { "op": "replace", "path": "/multilineFieldsFormat/System.Description", "value": "markdown" },
  { "op": "replace", "path": "/fields/System.Description", "value": "## Overview\n..." }
]
```

Both ops are required — the format-path patch alone won't re-render an html-flagged field, and the value patch alone won't flip the flag.

## Input contract

Source strings in the Plan Artifact are RAW — write plain Markdown, do NOT HTML-escape. The script wraps code-block content in triple-backtick fences (with a language hint) and renders Gherkin as a ```gherkin block. `additional_sections[].body` is inserted verbatim, so it may contain Markdown tables, prose, links, or nested fenced code.

## Invariants the script enforces

- The plain-language acceptance-criteria bullets (`acceptance_criteria`) appear ONLY in `acceptance_criteria_markdown`, never in `description_markdown`. Gherkin acceptance *scenarios* are a separate, intentional Description section (`gherkin_scenarios`) rendered as a ```gherkin fenced block — they are not the plain bullet list.
- Sections absent or empty in `description_sections` are omitted entirely (no empty headings).
- `entities` renders under a `## New Entities` heading, one `### {name}` + fenced block per entity (all fields in the block).
- `gherkin_scenarios` and each entity `definition` render inside fenced code blocks.
- `additional_sections` (array of `{ heading, body }`) renders each as a `## {heading}` followed by its raw Markdown body — this is the escape hatch for domain content the fixed sections can't hold (tables, reference notes, accessibility notes), mirroring the gold-standard PBI shape.
- Bullet lists render as `- item`, one per array element.
- Section order: Overview → User Story → Developer Context & Goals → additional_sections → New Entities → File Targets → Controller Method Signatures → Sample Request/Response → Error Response Contract → Idempotency → Conflict Handling → Security → Acceptance Scenarios (Gherkin) → Testing → Docs & Swagger. (This matches the HTML skill's order, plus the Markdown-only `overview` and `additional_sections`.)

## Relationship to the HTML skill

`render-plan-artifact` (HTML) is retained unchanged for any consumer that needs HTML. It does NOT render `overview` or `additional_sections` (Markdown-only fields). For a clean A/B comparison, render the same Plan Artifact through both skills and compare; if you use `overview`/`additional_sections`, the HTML output will omit them, so fold that content into the shared sections when authoring an HTML PBI.
