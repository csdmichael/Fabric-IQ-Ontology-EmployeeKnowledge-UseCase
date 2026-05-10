#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fabric IQ local deployment wrapper (Windows / PowerShell)

.DESCRIPTION
    Runs Terraform to provision Azure infrastructure, prepares source data,
    and optionally uploads data files to blob storage.

    For full CI/CD deployment use the GitHub Actions workflow instead:
    Actions -> Deploy Infrastructure and Artifacts -> Run workflow -> apply=true

.PARAMETER SubscriptionId
    Azure subscription ID (required)

.PARAMETER Apply
    Run terraform apply. Omit to plan-only (dry run).

.PARAMETER UploadData
    Upload data files to Azure Blob Storage after apply.

.EXAMPLE
    .\scripts\deploy-complete-solution.ps1 -SubscriptionId "YOUR_SUB_ID" -Apply
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [switch]$Apply,

    [switch]$UploadData
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot  = Split-Path -Parent $PSScriptRoot
$TfDir     = Join-Path $RepoRoot "terraform"
$VarFile   = Join-Path $RepoRoot "config/terraform.tfvars.json"

function Write-Step([string]$Msg) { Write-Host "[->] $Msg" -ForegroundColor Cyan  }
function Write-Ok  ([string]$Msg) { Write-Host "[OK] $Msg" -ForegroundColor Green  }
function Write-Warn([string]$Msg) { Write-Host "[!!] $Msg" -ForegroundColor Yellow }
function Write-Err ([string]$Msg) { Write-Host "[XX] $Msg" -ForegroundColor Red    }

# ── Prerequisites ─────────────────────────────────────────────────────────────

Write-Step "Checking prerequisites..."
foreach ($tool in @("az","terraform","python","git")) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
        Write-Ok "$tool found"
    } else {
        Write-Err "$tool not found – install it before running this script"
        exit 1
    }
}

# ── Azure login ───────────────────────────────────────────────────────────────

Write-Step "Setting Azure subscription to $SubscriptionId..."
az account set --subscription $SubscriptionId
Write-Ok "Subscription set"

# ── Data preparation ──────────────────────────────────────────────────────────

Write-Step "Running data preparation script..."
try {
    python (Join-Path $RepoRoot "scripts/populate_fabric_complete.py")
    Write-Ok "Data preparation complete"
} catch {
    Write-Warn "Data preparation failed: $($_.Exception.Message)"
}

# ── Terraform ─────────────────────────────────────────────────────────────────

Write-Step "Initialising Terraform..."
Push-Location $TfDir
try {
    terraform init
    Write-Ok "Terraform init complete"

    Write-Step "Running Terraform plan..."
    terraform plan -var-file="$VarFile" -out="$TfDir/tfplan"
    Write-Ok "Terraform plan complete"

    if ($Apply) {
        Write-Step "Applying Terraform plan..."
        terraform apply "$TfDir/tfplan"
        Write-Ok "Terraform apply complete"
        Remove-Item "$TfDir/tfplan" -ErrorAction SilentlyContinue
    } else {
        Write-Warn "Dry-run only. Pass -Apply to provision infrastructure."
    }
} finally {
    Pop-Location
}

# ── Data upload ───────────────────────────────────────────────────────────────

if ($UploadData -and $Apply) {
    Write-Step "Uploading data files to Azure Blob Storage..."
    $Cfg = Get-Content $VarFile | ConvertFrom-Json
    $Account   = $Cfg.storage_account_name
    $Container = $Cfg.raw_container_name

    foreach ($f in @("employees.json","digital_assets.json","contributions.json",
                      "projects.json","org_hierarchy.json","emails.json")) {
        $Src = Join-Path $RepoRoot "data/$f"
        if (Test-Path $Src) {
            az storage blob upload `
                --account-name $Account `
                --container-name $Container `
                --name $f `
                --file $Src `
                --overwrite `
                --auth-mode login `
                --output none
            Write-Ok "Uploaded $f"
        } else {
            Write-Warn "$f not found – skipping"
        }
    }
} elseif ($UploadData) {
    Write-Warn "Skipping data upload — requires -Apply to be set as well"
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "==============================" -ForegroundColor Cyan
Write-Host " Deployment summary"           -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

if ($Apply) {
    $Cfg     = Get-Content $VarFile | ConvertFrom-Json
    $ApiName = $Cfg.api_app_service_name
    $UiName  = $Cfg.ui_app_service_name
    Write-Ok "Infrastructure applied"
    Write-Host ""
    Write-Host "  API:  https://${ApiName}.azurewebsites.net/health"
    Write-Host "  UI:   https://${UiName}.azurewebsites.net"
    Write-Host "  Docs: https://${ApiName}.azurewebsites.net/docs"
} else {
    Write-Warn "Infrastructure not applied (plan only)"
    Write-Host ""
    Write-Host "  Re-run with -Apply to provision:"
    Write-Host "  .\scripts\deploy-complete-solution.ps1 -SubscriptionId $SubscriptionId -Apply"
}

Write-Host ""
Write-Host "  For full CI/CD deployment, push to main or trigger the"
Write-Host "  'Deploy Infrastructure and Artifacts' workflow in GitHub Actions."
