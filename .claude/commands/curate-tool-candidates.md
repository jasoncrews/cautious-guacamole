---
description: Triage tool-candidates.jsonl for the periodic tool-extraction review.
---

Read `.claude/agents/tool-candidates.jsonl` (relative to the repo root). If the file is empty, say so and stop.

For each record, classify as one of: `promote`, `keep-watching`, `drop`.

Decision rules:
- **promote** when `occurrences >= 3`, OR the code is substantive (≈30+ lines), OR the user has manually flagged this pattern in conversation.
- **keep-watching** when `occurrences < 3` and the pattern hasn't matured. Do not drop early.
- **drop** when the entry is stale (`last_seen` is more than 60 days before today's date AND `occurrences == 1`), or when the purpose is already covered by an extracted skill/script.

Output:
1. A markdown table with columns: `purpose | occurrences | last_seen | recommendation | rationale`.
2. For each `promote` row, a 5-line implementation sketch covering: where it lives (skill / script / MCP / new agent tool), input/output API, and any non-obvious behavior or invariant.

Do NOT modify `tool-candidates.jsonl` in this run. Output only.
