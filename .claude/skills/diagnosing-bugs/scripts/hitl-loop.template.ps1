# Human-in-the-loop reproduction loop (PowerShell).
# Copy this file, edit the steps below, and run it.
# The agent runs the script; the user follows prompts in their terminal.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File hitl-loop.template.ps1
#
# Two helpers:
#   Step "<instruction>"            -> show instruction, wait for Enter
#   Capture -Name VAR "<question>"  -> show question, read response into $VAR
#
# At the end, captured values are printed as KEY=VALUE for the agent to parse.

$ErrorActionPreference = 'Stop'
$captured = [ordered]@{}

function Step {
    param([Parameter(Mandatory)][string]$Instruction)
    Write-Host "`n>>> $Instruction"
    Read-Host "    [Enter when done]" | Out-Null
}

function Capture {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Question
    )
    Write-Host "`n>>> $Question"
    $answer = Read-Host "    >"
    $captured[$Name] = $answer
}

# --- edit below ---------------------------------------------------------

Step "Open the app at https://localhost:5001 and sign in."

Capture -Name ERRORED "Click the 'Export' button. Did it throw an error? (y/n)"

Capture -Name ERROR_MSG "Paste the error message (or 'none'):"

# --- edit above ---------------------------------------------------------

Write-Host "`n--- Captured ---"
foreach ($k in $captured.Keys) {
    Write-Host ("{0}={1}" -f $k, $captured[$k])
}
