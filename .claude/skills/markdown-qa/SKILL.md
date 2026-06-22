---
name: markdown-qa
description: This skill should be used after generating a folder of Markdown artifacts (e.g. /analyze-legacy writing .claude/plans/legacy-<module-slug>/) to deterministically normalize formatting and validate cross-file links — no AI involved. Runs a bundled Node script (ported from herman-documenter's qa_lists tooling) that fixes list formatting (blank line before lists, 2-space indents, `*` bullets, code-block-aware) and bold spacing (`** text**` → `**text**`), and reports broken relative links between the artifacts.
disable-model-invocation: false
allowed-tools: Bash, PowerShell
---

# Markdown QA (deterministic)

Normalizes generated Markdown and validates cross-file links in one pass — the native port of herman-documenter's automated `qa_lists` phase (`lib/markdown-processor.js`). Deterministic hygiene: run it, report the output, move on. It is **not a quality gate** — broken links and unfixable issues are reported for the orchestrator/human, never block the pipeline.

Invoke the bundled script on the artifact folder:

```bash
node "${CLAUDE_SKILL_DIR}/scripts/fix-markdown.js" "<absolute-folder-path>" --check-links
```

The script:

1. **Fixes in place** (idempotent), for every `.md` file in the folder (recursive):
   - List formatting: blank line inserted before a list that follows text; indentation normalized to 2 spaces per level; bullet marker normalized to `*`. Fenced code blocks (``` / ~~~) are never touched.
   - Bold spacing: `** text**` → `**text**`.
   - YAML frontmatter is preserved untouched.
2. **With `--check-links`**: collects every relative Markdown link/image (`[x](other.md)`, `[x](./sub/file.md#anchor)`), resolves it against the linking file's directory, and reports targets that don't exist. External (`http(s):`, `mailto:`) and pure-anchor (`#…`) links are skipped.

Output (stdout): a `Fixed:` list of changed files (empty if everything was already clean) and a `Broken links:` list (`file → target`). Exit code 0 on success even when broken links are found (they are findings, not failures); exit code 1 only for usage/IO errors.

Use `--dry-run` to report what would change without writing.

## Fallback

If `node` is not available on the machine, **skip this step with a warning** in the run report — formatting hygiene must never block an analysis run. Do not attempt to reproduce the fixes by hand-editing.
