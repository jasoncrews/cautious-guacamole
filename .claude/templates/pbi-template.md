# StarterPack3 PBI Template (Markdown)

This is the canonical shape of a Product Backlog Item for this team. It is written to be **good for two audiences at once**:

- **A human** reviewing/improving the PBI in the Azure DevOps editor (Markdown is easy to edit — no escaped HTML).
- **The `sp3-implementation-planner` agent** that picks the PBI up once a human moves it from **New → Approved** and turns it into a TDD implementation plan.

It is modeled on the StarterPack V3 gold-standard PBI shape plus the team's acceptance-criteria convention.

> **State gate — human only.** No agent ever moves a PBI from **New** to **Approved** (or any other state). Authoring agents create PBIs in **New**. The human reviews, improves, and is the *only* actor who approves. Implementation only begins after a human approval.

---

## Two fields, two jobs

A PBI lives in two Azure DevOps fields. Keep them separate:

| Field | Format | Holds |
|---|---|---|
| `System.Description` | Markdown | Everything below **except** the plain AC bullets: Overview, User Story, entities, implementation notes, **Gherkin acceptance scenarios**, files, etc. |
| `Microsoft.VSTS.Common.AcceptanceCriteria` | Markdown | ONLY the concise, plain-language, testable AC bullets. No Gherkin here. |

Both fields must have their Azure DevOps format flag set to **Markdown** (see `render-plan-artifact-markdown` skill). Gherkin scenarios live in the **Description**; the plain bullets live in the **AcceptanceCriteria** field. Never duplicate one into the other.

---

## Description structure (Markdown)

Use these `##` sections, in this order. **Bold = expected on most PBIs; the rest are optional — include a section only when it adds signal.** Omit empty sections rather than leaving a hollow heading.

```markdown
## Overview
1–3 sentences: what this delivers and why it matters. The elevator pitch.

## User Story
As a <role>, I need <capability> so that <business value>.

## Developer Context & Goals       (optional)
- Bullet context the implementer needs: the analog module to mirror, constraints, decisions already made.

## <Any domain section>            (optional, repeatable — "additional_sections")
Free-form Markdown for content the fixed sections can't hold: a mapping **table**, a
reference to existing code with file + line numbers, accessibility notes, a screenshot link.
e.g. "## Status Map", "## Color Map", "## Reference", "## Accessibility Notes".

## New Entities                    (REQUIRED whenever the PBI introduces a new entity/model/table)
### <EntityName> : EntityBase
\```
WidgetId: Guid (PK, required)
TenantId: Guid (required)
Name: string (required, max 100)
SerialNumber: string (required, max 50, unique per tenant)
Status: string (Active | Inactive | Retired)
# Relationships — include BOTH the FK id and the navigation property:
EmployeeId: Guid (FK -> Employee, required)
Employee: Employee (navigation, [ForeignKey("EmployeeId")])
WidgetParts: List<WidgetPart> (navigation collection — inverse side, when the entity owns children)
\```
- **Always inherit `EntityBase`** (from `SP3.Shared.Server.EFCore`) — declare the entity as `<Name> : EntityBase`. It supplies the standard audit fields (`CreatedBy`, `CreatedDateTime`, `ModifiedBy`, `ModifiedDateTime`), so **do NOT list or redefine audit fields** — list only the entity-specific fields.
- **List EVERY entity-specific field**, one per line, with type + key / nullability / constraints. Show the complete shape, not a sample.
- **Add the navigation properties the entity needs.** For each relationship, include the FK id (`<Other>Id: Guid`) **and** the navigation property (`<Other>: <Other>`), plus inverse collections (`List<Child>`) where the entity owns children — matching the repo convention (`[ForeignKey("EmployeeId")] public virtual Employee Employee { get; set; }`).

## File Targets / Code Locations   (optional but recommended)
- `Path/To/File.cs` (new|modify) — purpose

## Controller Method Signatures    (optional)  -> ```csharp fenced block
## Sample Request/Response          (optional)  -> ```json fenced block
## Error Response Contract          (optional)  -> ```json fenced block
## Idempotency / Conflict Handling / Security   (optional bullet lists)

## Acceptance Scenarios (Gherkin)   (REQUIRED for any behavioral PBI)
\```gherkin
Feature: <feature>

  Scenario: <name>
    Given <precondition>
    When <action>
    Then <observable outcome>
    And <...>
\```

## Testing                         (optional bullet list)
## Docs & Swagger                  (optional bullet list)
```

## AcceptanceCriteria field (Markdown) — separate field

Concise, plain-language, **testable** bullets. NOT Gherkin. These are the checklist a reviewer and Definition-of-Done check read:

```markdown
- An admin can create, view, edit, and delete widgets.
- Serial numbers are unique within a tenant; duplicates are rejected with a clear validation message.
- The widget list is scoped to the caller's tenant, paged, and sortable.
- Status is restricted to Active, Inactive, or Retired.
```

---

## What makes a PBI "approvable" (the bar the human is checking, and what the agent needs)

- **Overview + User Story** make the intent and value clear.
- **Every behavioral expectation has a Gherkin scenario** in the Description, and **every scenario is mirrored by a plain AC bullet** in the AcceptanceCriteria field (and vice-versa). This bidirectional coverage is exactly what the planner turns into tests.
- **New entities are fully specified** in a `## New Entities` code block: declared `: EntityBase` (audit fields inherited, not redefined), every entity-specific field listed, and the **navigation properties** for their relationships (FK id + nav property, plus inverse collections).
- **No tasks, no effort.** Do not add child tasks or story points/hours — developers do that in sprint planning.
- The PBI is **self-contained**: an implementer who has never seen the conversation could build it from the PBI alone.

---

## Worked mini-example

**Title:** `[Widget] Add Widget tracking CRUD`

**Description (Markdown):**

```markdown
## Overview
Add full CRUD for Widget tracking in the Admin UI so facilities staff can track widgets per tenant. Mirrors the existing Movie module.

## User Story
As a facilities admin, I need to create, view, edit, and delete widgets so that I can track them across the tenant.

## New Entities
### Widget : EntityBase
\```
WidgetId: Guid (PK, required)
TenantId: Guid (required)
Name: string (required, max 100)
SerialNumber: string (required, max 50, unique per tenant)
Status: string (Active | Inactive | Retired)
Location: string (nullable, max 100)
AssignedToEmployeeId: Guid (FK -> Employee, nullable)
AssignedToEmployee: Employee (navigation, [ForeignKey("AssignedToEmployeeId")])
\```
(Audit fields — CreatedBy/CreatedDateTime/ModifiedBy/ModifiedDateTime — are inherited from EntityBase and intentionally not listed.)

## Acceptance Scenarios (Gherkin)
\```gherkin
Feature: Widget tracking CRUD

  Scenario: Create a widget
    Given an authenticated facilities admin
    When they submit a widget with a unique serial number
    Then the widget is persisted with a generated id
    And it appears in the widget list for their tenant

  Scenario: Reject duplicate serial number
    Given a widget with serial number "SN-100" already exists for the tenant
    When the admin submits another widget with serial number "SN-100"
    Then the request is rejected with a validation error
\```

## File Targets / Code Locations
- `StarterPack3.Application.Api/Data/Entity/Widget.cs` (new) — Widget entity
- `StarterPack3.Admin.UI/Client/Pages/Widget/WidgetList.razor` (new) — admin grid
```

**AcceptanceCriteria field (Markdown):**

```markdown
- An admin can create, view, edit, and delete widgets.
- Serial numbers are unique within a tenant; duplicates are rejected with a clear validation message.
- The widget list is scoped to the caller's tenant, paged, and sortable.
- Status is restricted to Active, Inactive, or Retired.
```

---

## How this gets produced and consumed

- **Authoring:** the `azure-devops-business-analyst` agent drafts a Plan Artifact and renders it to this shape via the `render-plan-artifact-markdown` skill, then creates the PBI in **New**. This team's PBIs are **always Markdown** (the HTML `render-plan-artifact` skill exists only for non-team/external consumers).
- **Improving:** a human edits the Markdown directly in Azure DevOps — add detail, tighten scenarios, fix the entity shape — then approves.
- **Implementing:** once **Approved**, `/implement-pbi` hands the PBI to `sp3-implementation-planner`, which reads the Gherkin scenarios, AC bullets, and entity blocks as the definition of done.
