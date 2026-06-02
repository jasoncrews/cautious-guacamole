---
description: Plan a legacy-module replication as Azure DevOps PBIs + parent Feature, following the StarterPack V3 CRUD guide
argument-hint: <module-name> <legacy-repo-path>
---

Please make a plan to replicate the **{first argument}** of this old project **{remaining arguments — absolute path}** in this project. Create the steps in the style of product backlog items that increase in complexity, starting with just creating the base area with CRUD functionality, then adding features with each PBI. Follow the StarterPack V3 CRUD guide as the reference:

https://uisapp2.iu.edu/confluence-prd/spaces/EAS/pages/755697093/Creating+StarterPack+V3+CRUD

Permissions are role/group based — use the standard StarterPack approach (policies declared centrally, e.g. `Permissions.cs`, gated via `[Authorize(Policy = "...")]`). Nothing custom.

Where lookup/control tables would normally exist, prefer **constants files in the shared project** (the `*.Shared` project, mirroring the StarterPack constants pattern) over DB-backed lookup entities, to reduce administrative work. Use real entities only when the data has a live source (e.g. an upstream integration feed) or churns frequently enough to warrant a maintenance UI — flag any borderline cases.

For any UI, follow the **Rivet** design system — specify Rivet components and utility classes rather than custom markup/CSS (look them up via the `rivet-design-system` MCP tools if available).

After the plan is approved, add a Feature in Azure DevOps for this and link the PBIs to it. **Use HTML format for every work item description (both the Feature and all child PBIs).**

---

**Arguments:** $ARGUMENTS

If either the module name or the legacy repo path is missing, ask the user to supply it before continuing.

## How to execute

1. **Explore the legacy module** at the given path — summarize its pages, business logic, entities, and workflows. Don't dump file contents.
2. **Fetch the StarterPack V3 CRUD guide** (link above). If it's unreachable (on-prem Confluence, auth-gated), fall back to using the target StarterPack repo itself as the reference — find the closest existing CRUD module and mirror its structure.
3. **Draft the PBI plan**:
   - PBI 1: base area scaffold + core CRUD only.
   - PBI 2+: each adds one logical capability (lookup constants, online submission UI, junction tables, attachments, workflow, notifications, claims/sub-modules, search/export, etc.).
   - Each PBI should be independently shippable when possible.
   - For each PBI include title, short description, scope bullets, and any non-obvious dependencies.
4. **Confirm with the user** before creating any work items.
5. **On approval**, create the work items via the `wit_*` MCP tools. Ask the user for the target Azure DevOps project (and area/iteration if relevant) if it isn't already known — do not assume a project name.

## HTML formatting requirements (don't skip — the format flag is easy to miss)

Each work item description **must** end up with `multilineFieldsFormat.System.Description = "html"` and contain real HTML tags (`<h2>`, `<p>`, `<ul>`, `<li>`, `<code>`, `<strong>`).

### Creating the parent Feature
Use `wit_create_work_item` and pass `format: "Html"` **inside the field object** for `System.Description`:

```json
{
  "name": "System.Description",
  "format": "Html",
  "value": "<h2>Overview</h2>..."
}
```

### Creating child PBIs
`wit_add_child_work_items` accepts `format` **per item, NOT at the top level.** Each entry in the `items` array must include `"format": "Html"`. Putting it at the top level (next to `items`) is silently ignored and the PBIs end up as markdown.

```json
{
  "parentId": <featureId>,
  "workItemType": "Product Backlog Item",
  "items": [
    { "title": "...", "description": "<h2>Goal</h2>...", "format": "Html" },
    ...
  ]
}
```

### Verifying
After creation, check the response: each work item's `multilineFieldsFormat.System.Description` should be `"html"`. If any came back as `"markdown"`, fix with `wit_update_work_item` using **two patch operations** in a single call:

```json
[
  { "op": "replace", "path": "/multilineFieldsFormat/System.Description", "value": "html" },
  { "op": "replace", "path": "/fields/System.Description", "value": "<h2>...</h2>..." }
]
```

Both ops are required — the format-path patch alone won't change a markdown body to HTML rendering, and the field-value patch alone won't flip the format flag.
