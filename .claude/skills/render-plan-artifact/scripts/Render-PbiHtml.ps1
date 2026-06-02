[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
    [string]$PlanJson
)

if (-not $PlanJson) {
    $PlanJson = [Console]::In.ReadToEnd()
}

function ConvertTo-HtmlText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

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

function Format-BulletList {
    param([object[]]$Items)
    if (-not (Test-HasContent $Items)) { return '' }
    $li = ($Items | ForEach-Object { "<li>$(ConvertTo-HtmlText $_)</li>" }) -join "`n"
    return "<ul>`n$li`n</ul>"
}

function Format-CodeBlock {
    param([string]$Code)
    if ([string]::IsNullOrWhiteSpace($Code)) { return '' }
    return "<pre><code>$(ConvertTo-HtmlText $Code)</code></pre>"
}

function Format-Section {
    param([string]$Heading, [string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return '' }
    return "<p><strong>$(ConvertTo-HtmlText $Heading)</strong></p>`n$Content"
}

function Format-FileTargets {
    param([object[]]$Targets)
    if (-not (Test-HasContent $Targets)) { return '' }
    $li = ($Targets | ForEach-Object {
            $path = ConvertTo-HtmlText $_.path
            $action = ConvertTo-HtmlText $_.action
            $purpose = ConvertTo-HtmlText $_.purpose
            "<li><code>$path</code> ($action) &mdash; $purpose</li>"
        }) -join "`n"
    return "<ul>`n$li`n</ul>"
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

    $us = Get-OptionalProp $pbi 'user_story'
    if ($us) {
        $asA = ConvertTo-HtmlText (Get-OptionalProp $us 'as_a')
        $iWant = ConvertTo-HtmlText (Get-OptionalProp $us 'i_want')
        $soThat = ConvertTo-HtmlText (Get-OptionalProp $us 'so_that')
        $sections.Add("<p>As a $asA I need $iWant so that $soThat.</p>") | Out-Null
    }

    $ds = Get-OptionalProp $pbi 'description_sections'
    if ($ds) {
        $val = Get-OptionalProp $ds 'developer_context_and_goals'
        if (Test-HasContent $val) {
            $sections.Add((Format-Section 'Developer Context & Goals' (Format-BulletList $val))) | Out-Null
        }

        $val = Get-OptionalProp $ds 'file_targets'
        if (Test-HasContent $val) {
            $sections.Add((Format-Section 'File targets / code locations' (Format-FileTargets $val))) | Out-Null
        }

        $val = Get-OptionalProp $ds 'controller_signatures'
        if (Test-HasContent $val) {
            $sections.Add((Format-Section 'Controller method signatures (suggested)' (Format-CodeBlock $val))) | Out-Null
        }

        $val = Get-OptionalProp $ds 'sample_request_response'
        if (Test-HasContent $val) {
            $sections.Add((Format-Section 'Sample request/response' (Format-CodeBlock $val))) | Out-Null
        }

        $val = Get-OptionalProp $ds 'error_response_contract'
        if (Test-HasContent $val) {
            $sections.Add((Format-Section 'Error response contract' (Format-CodeBlock $val))) | Out-Null
        }

        $val = Get-OptionalProp $ds 'idempotency'
        if (Test-HasContent $val) {
            $sections.Add((Format-Section 'Idempotency' (Format-BulletList $val))) | Out-Null
        }

        $val = Get-OptionalProp $ds 'conflict_handling'
        if (Test-HasContent $val) {
            $sections.Add((Format-Section 'Conflict handling' (Format-BulletList $val))) | Out-Null
        }

        $val = Get-OptionalProp $ds 'security'
        if (Test-HasContent $val) {
            $sections.Add((Format-Section 'Security' (Format-BulletList $val))) | Out-Null
        }

        $val = Get-OptionalProp $ds 'testing'
        if (Test-HasContent $val) {
            $sections.Add((Format-Section 'Testing' (Format-BulletList $val))) | Out-Null
        }

        $val = Get-OptionalProp $ds 'docs_and_swagger'
        if (Test-HasContent $val) {
            $sections.Add((Format-Section 'Docs & Swagger' (Format-BulletList $val))) | Out-Null
        }
    }

    $descriptionHtml = ($sections | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n`n"

    $ac = Get-OptionalProp $pbi 'acceptance_criteria'
    $acHtml = ''
    if (Test-HasContent $ac) {
        $acHtml = Format-BulletList $ac
    }

    $record = [PSCustomObject]@{
        draft_id                 = (Get-OptionalProp $pbi 'draft_id')
        description_html         = $descriptionHtml
        acceptance_criteria_html = $acHtml
    }

    $jsonItems += (ConvertTo-Json -InputObject $record -Compress -Depth 10)
}

Write-Output ('[' + ($jsonItems -join ',') + ']')
