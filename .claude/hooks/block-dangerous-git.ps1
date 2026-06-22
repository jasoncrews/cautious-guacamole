# PreToolUse hook: block dangerous git commands before Claude runs them.
# Wired into .claude/settings.json for the Bash and PowerShell tools.
# Reads the tool-call JSON on stdin; exit 2 blocks the call and feeds the
# stderr message back to Claude. Exit 0 lets the call through.
#
# Aligns with the pack's safety model: agents leave work UNCOMMITTED on a
# feature branch; the human commits, pushes, and opens the PR themselves.
#
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads .ps1 as the
# system ANSI codepage, so non-ASCII characters (em-dashes, smart quotes)
# corrupt and break parsing.

$ErrorActionPreference = 'Stop'

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }

$command = $payload.tool_input.command
if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }

# Dangerous patterns (regex, case-insensitive). \s+ tolerates extra spacing.
$dangerous = @(
    'git\s+push',
    'git\s+reset\s+--hard',
    'git\s+clean\s+-fd',
    'git\s+clean\s+-f',
    'git\s+branch\s+-D',
    'git\s+checkout\s+\.',
    'git\s+restore\s+\.',
    'push\s+--force',
    'reset\s+--hard'
    # To enforce the pack's never-commit rule on agents, add: 'git\s+commit'
    # (the human still commits via their own terminal / the ! prefix, which
    # bypasses this hook).
)

foreach ($pattern in $dangerous) {
    if ($command -match $pattern) {
        [Console]::Error.WriteLine("BLOCKED: '$command' matches dangerous pattern '$pattern'. You do not have authority to run this command - the human commits, pushes, and opens the PR for this pack's work.")
        exit 2
    }
}

exit 0
