#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ApiUrl = "https://fabric-iq-emp-knowledge-api.azurewebsites.net",

    [Parameter(Mandatory=$false)]
    [string]$UiUrl = "https://fabric-iq-emp-knowledge-ui.azurewebsites.net"
)

$ErrorActionPreference = "Stop"

function Write-Result {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Details
    )

    $prefix = if ($Ok) { "[OK]" } else { "[XX]" }
    $color = if ($Ok) { "Green" } else { "Red" }
    Write-Host "$prefix ${Name}: $Details" -ForegroundColor $color
}

$failed = $false

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Fabric IQ - Integration Smoke Test" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# API health
try {
    $r = Invoke-WebRequest -Uri "$ApiUrl/health" -UseBasicParsing -TimeoutSec 30
    $ok = $r.StatusCode -eq 200
    Write-Result "API health" $ok "status=$($r.StatusCode)"
    if (-not $ok) { $failed = $true }
} catch {
    Write-Result "API health" $false $_.Exception.Message
    $failed = $true
}

# API summary
try {
    $summary = Invoke-RestMethod -Uri "$ApiUrl/api/summary" -TimeoutSec 30
    $ok = ($summary.employees -eq 100) -and ($summary.contributions -eq 100) -and ($summary.digitalAssets -eq 800) -and ($summary.projects -eq 20)
    Write-Result "API summary counts" $ok "employees=$($summary.employees), contributions=$($summary.contributions), assets=$($summary.digitalAssets), projects=$($summary.projects)"
    if (-not $ok) { $failed = $true }
} catch {
    Write-Result "API summary counts" $false $_.Exception.Message
    $failed = $true
}

# Core API endpoints
$apiEndpoints = @(
    "/api/employees",
    "/api/projects",
    "/api/contributions",
    "/api/powerbi-reports",
    "/api/org-hierarchy",
    "/api/config/endpoints"
)

foreach ($ep in $apiEndpoints) {
    try {
        $r = Invoke-WebRequest -Uri "$ApiUrl$ep" -UseBasicParsing -TimeoutSec 30
        $ok = $r.StatusCode -eq 200
        Write-Result "Endpoint $ep" $ok "status=$($r.StatusCode)"
        if (-not $ok) { $failed = $true }
    } catch {
        Write-Result "Endpoint $ep" $false $_.Exception.Message
        $failed = $true
    }
}

# UI health
try {
    $uiResp = Invoke-WebRequest -Uri $UiUrl -UseBasicParsing -TimeoutSec 45
    $hasTitle = $uiResp.Content -like "*Fabric IQ*"
    $ok = ($uiResp.StatusCode -eq 200) -and $hasTitle
    Write-Result "UI availability" $ok "status=$($uiResp.StatusCode), titlePresent=$hasTitle"
    if (-not $ok) { $failed = $true }
} catch {
    Write-Result "UI availability" $false $_.Exception.Message
    $failed = $true
}

# Agent definitions and sample prompts
try {
    $empAgent = Get-Content "fabric/agents/employee_knowledge_agent.json" -Raw | ConvertFrom-Json
    $ok = $empAgent.samplePrompts.Count -ge 20
    Write-Result "Employee agent prompts" $ok "count=$($empAgent.samplePrompts.Count)"
    if (-not $ok) { $failed = $true }
} catch {
    Write-Result "Employee agent prompts" $false $_.Exception.Message
    $failed = $true
}

try {
    $sreAgent = Get-Content "fabric/agents/sre_agent.json" -Raw | ConvertFrom-Json
    $ok = $sreAgent.samplePrompts.Count -ge 10
    Write-Result "SRE agent prompts" $ok "count=$($sreAgent.samplePrompts.Count)"
    if (-not $ok) { $failed = $true }
} catch {
    Write-Result "SRE agent prompts" $false $_.Exception.Message
    $failed = $true
}

# Sample prompt feasibility checks against data
try {
    $employees = Invoke-RestMethod -Uri "$ApiUrl/api/employees" -TimeoutSec 30
    $contributions = Invoke-RestMethod -Uri "$ApiUrl/api/contributions" -TimeoutSec 30
    $assets = Invoke-RestMethod -Uri "$ApiUrl/api/digital-assets" -TimeoutSec 30

    $emp014 = $employees | Where-Object { $_.employeeId -eq "EMP014" } | Select-Object -First 1
    $prompt1Ok = $null -ne $emp014
    $prompt1Message = "employee not found"
    if ($prompt1Ok) { $prompt1Message = "employee exists" }
    Write-Result "Prompt check: assets for EMP014" $prompt1Ok $prompt1Message
    if (-not $prompt1Ok) { $failed = $true }

    $opsContrib = $contributions | Where-Object { $_.department -eq "Operations" }
    $prompt2Ok = ($opsContrib | Measure-Object).Count -gt 0
    Write-Result "Prompt check: Operations confidence comparison" $prompt2Ok "matchingRecords=$((($opsContrib | Measure-Object).Count))"
    if (-not $prompt2Ok) { $failed = $true }

    $lowConfidence = $assets | Where-Object { ($_.confidenceScore -as [double]) -lt 0.70 }
    $prompt3Ok = ($lowConfidence | Measure-Object).Count -gt 0
    Write-Result "Prompt check: low-confidence assets" $prompt3Ok "matchingRecords=$((($lowConfidence | Measure-Object).Count))"
    if (-not $prompt3Ok) { $failed = $true }
} catch {
    Write-Result "Prompt feasibility checks" $false $_.Exception.Message
    $failed = $true
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
if ($failed) {
    Write-Host "Integration result: FAILED" -ForegroundColor Red
    exit 1
}

Write-Host "Integration result: PASSED" -ForegroundColor Green
exit 0
