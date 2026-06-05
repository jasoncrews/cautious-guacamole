# StarterPack3 Feature & Epic Templates + Decomposition Heuristic

The sibling of `pbi-template.md`. That file defines the **leaf** (a PBI). This file defines the **parents** (Feature, Epic) and the **heuristic** the `azure-devops-business-analyst` uses to break a big ask down into a properly-sized, linked tree.

> **State gate — human only.** No agent ever moves *any* work item (Epic, Feature, or PBI) from **New** to **Approved**. Authoring agents create everything in **New**. The human reviews, improves, and is the only actor who approves. This applies at every level of the hierarchy.
>
> **No tasks, no effort — at every level.** Agents never create child Tasks and never set story points / hours on an Epic, Feature, or PBI. Task breakdown and estimation happen in sprint planning.

---

## The hierarchy

```
Epic        a large, multi-sprint business initiative        → decomposes into Features
  └─ Feature   a shippable increment / coherent capability    → decomposes into PBIs
       └─ PBI       an INVEST vertical slice, fits a sprint    → the leaf the implementer builds
```

A decomposition does **not** have to start at the top. Pick the entry level by the size of the ask:

| Input | Produce |
|---|---|
| A large initiative spanning several capabilities | Epic → Features → PBIs |
| One coherent capability (e.g. "MaintBid overtime bid") | Feature → PBIs |
| A single small ask | one (or a few) PBIs, no parent |
| An **existing** Epic/Feature work-item id | children **under** the existing parent (never recreate the parent) |

Parent-link with `wit_work_items_link` (`type: "parent"`); a PBI's parent is a Feature or an Epic, **never another PBI**.

---

## Right-sizing (the bar at each level)

- **Epic** — too big for one increment; only justified when there are *multiple* Features. If it would have a single Feature, it's a Feature. Epics rarely own entities themselves.
- **Feature** — a coherent, demoable capability that a few PBIs deliver. If it would be a single PBI, it's a PBI. If it would need 10+ PBIs across unrelated areas, it's probably an Epic.
- **PBI** — a **vertical slice**: independently demoable, INVEST (Independent, Negotiable, Valuable, Estimable, Small, Testable), fits in a sprint. Not a mega-PBI hiding a whole subsystem; not noise so small it should be an AC bullet on a larger PBI. Uses the full `pbi-template.md` shape (Overview, User Story, New Entities, Gherkin, AC field).

---

## Decomposition heuristic — foundation-first vertical slices

This is how this team builds software (learned on MaintBid, Parking, OJL). When you decompose a Feature into PBIs:

1. **Lead with a foundation PBI** when the feature introduces new entities: data model + **all** FK-child entities + **one** migration + idempotent seed data. The schema ships once, FK-consistent. **Never split a schema across PBIs** — FK children land in the same PBI (one migration) as their parent. This PBI is `build_order: 1` and everything else depends on it.
2. **Then one PBI per user-facing capability / screen, as a vertical slice** — each cuts top-to-bottom through the stack: entity behavior → Application.Api endpoint(s) → BFF/Online (or Admin) server proxy → Refit interface → Razor page → functional tests. Each slice is independently demoable. Order slices by dependency (a "claim" action before the "my claims" list that reads it).
3. **Aggregating / dashboard / rollup PBIs come last** — they read from the slices, so they depend on them and must have a higher `build_order`.
4. **State an explicit build order and dependencies.** MaintBid was `1 → 3 → 2 → 4 → 5`. The build order is not always the listing order — sequence by what unblocks what.
5. **Surface scope cuts as POC decisions + open questions.** When you defer gating, a data source, or a screen for a POC, record it as a POC decision and (if it needs a product/SME call) an open question — never silently resolve a product decision.

---

## Feature — Markdown shape

A Feature's Description is **lighter than a PBI** — no entity code blocks, no Gherkin (those belong on the child PBIs). It frames *why* the capability exists and *what* its children are.

```markdown
## Overview
1–3 sentences: what capability this delivers and why it matters.

## Outcome & Value
The business outcome when this Feature is done, and who benefits.

## In Scope
- bullet
## Out of Scope
- bullet (what this Feature deliberately does NOT cover — e.g. supervisor authoring, gating)

## Child PBIs (build order)
1. [foundation] <PBI title> — data model + migration + seed
2. <PBI title> — vertical slice
3. ...
(last) <PBI title> — dashboard / rollup

## Dependencies
- Cross-feature or external blockers.

## Open Questions
- Items needing a product/SME decision before the children can be fully built.
```

The "Child PBIs" list is authoring guidance; the authoritative parent↔child relationship is the work-item link, and the durable record is the backlog doc in `Data/Plans/feature-<id>-<slug>-backlog.md`.

---

## Epic — Markdown shape

```markdown
## Overview
2–4 sentences: the initiative and the problem it solves.

## Outcome & Value
The measurable business outcome; the strategic value.

## In Scope
- the Features this Epic covers
## Out of Scope
- explicitly excluded areas

## Features
- <Feature title> — one-line purpose
- <Feature title> — one-line purpose

## Open Questions
- Initiative-level decisions for stakeholders.
```

---

## How this gets produced and consumed

- **Authoring / decomposing:** `azure-devops-business-analyst` (optimizer) drafts a hierarchical Plan Artifact, the `plan-reviewer` (evaluator) checks decomposition quality + hierarchy integrity, and on approval Phase 2 creates the tree parent-before-child in **New**, parent-linked, in build order. Entry point: `/decompose <epic-or-feature-id | description>`.
- **PBIs** are rendered with the `render-plan-artifact-markdown` skill (deterministic). **Features/Epics** are small, angle-bracket-free Markdown bodies authored from the shapes above at create time (creates preserve content safely).
- **Improving:** a human edits the Markdown directly in Azure DevOps, then approves (New → Approved).
- **Implementing:** once a PBI is Approved, `/implement-pbi` hands it to `sp3-implementation-planner` — the decomposition feeds the existing implementation pipeline unchanged.
