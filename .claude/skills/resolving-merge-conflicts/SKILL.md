---
name: resolving-merge-conflicts
description: "Use when you need to resolve an in-progress git merge/rebase conflict."
---

1. **See the current state** of the merge/rebase. Check git history, and the conflicting files.

2. **Find the primary sources** for each conflict. Understand deeply why each change was made, and what the original intent was. Read the commit messages, check the PRs, check original issues/tickets/PBIs.

3. **Resolve each hunk.** Preserve both intents where possible. Where incompatible, pick the one matching the merge's stated goal and note the trade-off. Do **not** invent new behaviour. Always resolve; never `--abort`.

4. Discover the project's **automated checks** and run them — typically `dotnet build`, then `dotnet test`, then `dotnet format`. Fix anything the merge broke.

5. **Stop at the finish line — do not commit.** This pack's agents never commit (work is handed to the human to commit and open the PR). Stage the resolved files, then **hand the finish to the human**: present a summary of every hunk you resolved and the trade-offs you made, and tell them the single command to finalize — `git commit` for a merge, or `git rebase --continue` for a rebase (which they re-run per remaining commit). Do not run that command yourself unless the human explicitly tells you to.
