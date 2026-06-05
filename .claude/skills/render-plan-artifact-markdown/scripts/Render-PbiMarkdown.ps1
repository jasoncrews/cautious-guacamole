[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [string]$PlanJson
)

if (-not $PlanJson) {
    $PlanJson = [Console]::In.ReadToEnd()
}

# Literal backtick + triple-backtick fence (built from char codes so the source
# itself stays readable and PowerShell never tries to treat them as escapes).
$bt = ([char]96).ToString()
$fence = $bt * 3
$dash = ([char]0x2014).ToString()

function Get-OptionalProp {
    param([object]$Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    if ($Obj.PSObject.Properties.Name -notcontains $Name) { return $null }
    return $Obj.$Name
}

function Test-HasContent {
    param([object]$Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [string]) { return -not [string]::IsNullOrWhiteSpace($Value) }
    if ($Value -is [System.Collections.IEnumerable]) { return @($Value).Count -gt 0 }
    return $true
}

function Format-Bullets {
    param([object[]]$Items)
    if (-not (Test-HasContent $Items)) { return '' }
    return (($Items | ForEach-Object { "- $_" }) -join "`n")
}

function Format-CodeBlock {
    param([string]$Code, [string]$Lang = '')
    if ([string]::IsNullOrWhiteSpace($Code)) { return '' }
    return "$fence$Lang`n$($Code.TrimEnd())`n$fence"
}

function Format-Section {
    param([string]$Heading, [string]$Body)
    if ([string]::IsNullOrWhiteSpace($Body)) { return '' }
    return "## $Heading`n$Body"
}

function Format-FileTargets {
    param([object[]]$Targets)
    if (-not (Test-HasContent $Targets)) { return '' }
    return (($Targets | ForEach-Object {
                "- $bt$($_.path)$bt ($($_.action)) $dash $($_.purpose)"
            }) -join "`n")
}

function Format-Entities {
    param([object[]]$Entities)
    if (-not (Test-HasContent $Entities)) { return '' }
    return (($Entities | ForEach-Object {
                "### $($_.name)`n$fence`n$(($_.definition).TrimEnd())`n$fence"
            }) -join "`n`n")
}

function Format-AdditionalSections {
    param([object[]]$Sections)
    if (-not (Test-HasContent $Sections)) { return '' }
    return (($Sections | ForEach-Object {
                "## $($_.heading)`n$(($_.body).TrimEnd())"
            }) -join "`n`n")
}

try {
    $plan = $PlanJson | ConvertFrom-Json -ErrorAction Stop
}
catch {
    Write-Error "Failed to parse PlanJson: $($_.Exception.Message)"
    exit 1
}

$pbis = @($plan.pbis)
$jsonItems = @()

foreach ($pbi in $pbis) {
    $sections = New-Object System.Collections.Generic.List[string]
    $ds = Get-OptionalProp $pbi 'description_sections'

    $overview = Get-OptionalProp $ds 'overview'
    if (Test-HasContent $overview) {
        $sections.Add((Format-Section 'Overview' $overview.TrimEnd())) | Out-Null
    }

    $us = Get-OptionalProp $pbi 'user_story'
    if ($us) {
        $asA = Get-OptionalProp $us 'as_a'
        $iWant = Get-OptionalProp $us 'i_want'
        $soThat = Get-OptionalProp $us 'so_that'
        $sections.Add("## User Story`nAs a $asA, I need $iWant so that $soThat.") | Out-Null
    }

    if ($ds) {
        $val = Get-OptionalProp $ds 'developer_context_and_goals'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'Developer Context & Goals' (Format-Bullets $val))) | Out-Null }

        $val = Get-OptionalProp $ds 'additional_sections'
        if (Test-HasContent $val) { $sections.Add((Format-AdditionalSections $val)) | Out-Null }

        $val = Get-OptionalProp $ds 'entities'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'New Entities' (Format-Entities $val))) | Out-Null }

        $val = Get-OptionalProp $ds 'file_targets'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'File Targets / Code Locations' (Format-FileTargets $val))) | Out-Null }

        $val = Get-OptionalProp $ds 'controller_signatures'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'Controller Method Signatures (suggested)' (Format-CodeBlock $val 'csharp'))) | Out-Null }

        $val = Get-OptionalProp $ds 'sample_request_response'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'Sample Request/Response' (Format-CodeBlock $val 'json'))) | Out-Null }

        $val = Get-OptionalProp $ds 'error_response_contract'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'Error Response Contract' (Format-CodeBlock $val 'json'))) | Out-Null }

        $val = Get-OptionalProp $ds 'idempotency'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'Idempotency' (Format-Bullets $val))) | Out-Null }

        $val = Get-OptionalProp $ds 'conflict_handling'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'Conflict Handling' (Format-Bullets $val))) | Out-Null }

        $val = Get-OptionalProp $ds 'security'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'Security' (Format-Bullets $val))) | Out-Null }

        $val = Get-OptionalProp $ds 'gherkin_scenarios'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'Acceptance Scenarios (Gherkin)' (Format-CodeBlock $val 'gherkin'))) | Out-Null }

        $val = Get-OptionalProp $ds 'testing'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'Testing' (Format-Bullets $val))) | Out-Null }

        $val = Get-OptionalProp $ds 'docs_and_swagger'
        if (Test-HasContent $val) { $sections.Add((Format-Section 'Docs & Swagger' (Format-Bullets $val))) | Out-Null }
    }

    $descriptionMarkdown = ($sections | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n`n"

    $ac = Get-OptionalProp $pbi 'acceptance_criteria'
    $acMarkdown = ''
    if (Test-HasContent $ac) { $acMarkdown = Format-Bullets $ac }

    $record = [PSCustomObject]@{
        draft_id                     = (Get-OptionalProp $pbi 'draft_id')
        format                       = 'markdown'
        description_markdown         = $descriptionMarkdown
        acceptance_criteria_markdown = $acMarkdown
    }

    $jsonItems += (ConvertTo-Json -InputObject $record -Compress -Depth 10)
}

Write-Output ('[' + ($jsonItems -join ',') + ']')
