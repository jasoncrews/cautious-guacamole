---
name: git-guardrails
description: Manage the PreToolUse hook that blocks dangerous git commands (push, reset --hard, clean, branch -D, checkout ./restore .) before Claude runs them. The pack ships this hook pre-wired and active. Use to customize the blocked patterns, change its scope, or verify it.
allowed-tools: Read, Edit, PowerShell, Bash
---

# Git Guardrails

A PreToolUse hook intercepts and blocks dangerous git commands before Claude executes them — enforcing the pack's safety model (agents leave work **uncommitted** on a feature branch; the human commits, pushes, and opens the PR).

**This pack ships the hook pre-wired and active** in `.claude/settings.json`, pointing at `.claude/hooks/block-dangerous-git.ps1` (PowerShell, Windows-first) for both the `Bash` and `PowerShell` tools. There is also a `block-dangerous-git.sh` bash fallback (requires `jq`). You don't need to install anything — use this skill only to customize, re-scope, or verify.

## What gets blocked

- `git push` (all variants, including `--force`)
- `git reset --hard`
- `git clean -f` / `git clean -fd`
- `git branch -D`
- `git checkout .` / `git restore .`

When blocked, Claude sees a message telling it that it does not have authority to run the command. The human still runs these themselves via their own terminal or the `!` prefix, which bypasses this hook.

## Customize the blocked patterns

Edit the `$dangerous` array in `.claude/hooks/block-dangerous-git.ps1` (and the `DANGEROUS_PATTERNS` array in the `.sh` fallback to match). Patterns are case-insensitive regex.

**Enforce never-commit:** to mechanically stop agents from committing, add `'git\s+commit'` to the array — there's a commented pointer in the script. The human's own `git commit` (terminal / `!` prefix) is unaffected.

## Change scope (project vs global)

The pack wires the hook at **project** scope (`.claude/settings.json`). To apply it to **all** projects instead, move the `hooks` block to `~/.claude/settings.json` and copy the script to `~/.claude/hooks/`, referencing it as `~/.claude/hooks/block-dangerous-git.ps1`. Merge into any existing `hooks.PreToolUse` array — don't overwrite other settings.

## Disable

Remove the `hooks` block from `.claude/settings.json` (the script files can stay).

## Verify

```powershell
'{"tool_input":{"command":"git push origin main"}}' | powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/block-dangerous-git.ps1; "exit=$LASTEXITCODE"
```

Should print a `BLOCKED:` message and `exit=2`. A safe command (e.g. `git status`) should print nothing and `exit=0`.
