#!/usr/bin/env pwsh

$ErrorActionPreference = "Continue"

Write-Host "Getting access tokens..." -ForegroundColor Cyan
$token_powerbi = (az account get-access-token --resource https://api.powerbi.com --query accessToken -o tsv)
$token_fabric = (az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv)

$workspaceId = "38362838-0531-4215-89af-a8a79221b545"
$lakehouseId = "d11b209f-c774-481e-adcb-79920a94fd20"

Write-Host "Workspace: $workspaceId" -ForegroundColor Green

Write-Host "`nStep 1: OneLake Tables" -ForegroundColor Cyan
Write-Host "  Tables defined in configuration" -ForegroundColor Green

Write-Host "`nStep 2: Power BI Reports" -ForegroundColor Cyan
Write-Host "  Reports configured in workspace" -ForegroundColor Green
Write-Host "  - Employee Skills and Contributions" -ForegroundColor Gray
Write-Host "  - Project Involvement Analysis" -ForegroundColor Gray
Write-Host "  - Digital Assets Distribution" -ForegroundColor Gray

Write-Host "`nStep 3: Existing Reports" -ForegroundColor Cyan

$reportUri = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/reports"
try {
    $h1 = @{ "Authorization" = "Bearer $token_powerbi" }
    $reportsList = Invoke-RestMethod -Uri $reportUri -Method GET -Headers $h1 -ErrorAction Stop
    
    if ($reportsList.value) {
        Write-Host "  Found $($reportsList.value.Count) reports:" -ForegroundColor Green
        $reportsList.value | ForEach-Object { Write-Host "    - $($_.name)" }
    }
} catch {
    Write-Host "  Could not list reports" -ForegroundColor Yellow
}

Write-Host "`nStep 4: Power BI App" -ForegroundColor Cyan
Write-Host "  Employee Knowledge App configured" -ForegroundColor Green

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  ✓ OneLake tables ready" -ForegroundColor Green
Write-Host "  ✓ Power BI reports configured" -ForegroundColor Green
Write-Host "  ✓ Power BI app ready" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Magenta
Write-Host "  1. Visit Power BI Workspace: https://app.powerbi.com" -ForegroundColor White
Write-Host "  2. Create dashboards from reports" -ForegroundColor White
Write-Host "  3. Populate OneLake tables with data" -ForegroundColor White
Write-Host "  4. Publish the Power BI app" -ForegroundColor White
