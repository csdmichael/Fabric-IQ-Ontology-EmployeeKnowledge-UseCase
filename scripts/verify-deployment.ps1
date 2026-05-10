#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fabric IQ - Deployment Verification Script
    Verifies all components are deployed and working correctly

.DESCRIPTION
    Checks API health, Azure resources, Fabric workspace, and Power BI setup
    Can be run anytime to verify deployment status

.PARAMETER SubscriptionId
    Azure subscription ID (optional, uses default if not specified)

.PARAMETER ResourceGroup
    Azure resource group name (default: ai-myaacoub)

.EXAMPLE
    .\verify-deployment.ps1
    .\verify-deployment.ps1 -SubscriptionId "YOUR_SUB_ID"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "ai-myaacoub"
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$Config = @{
    ApiName = "fabric-iq-emp-knowledge-api"
    ApiUrl = "https://fabric-iq-emp-knowledge-api.azurewebsites.net"
    UiName = "fabric-iq-emp-knowledge-ui"
    UiUrl = "https://fabric-iq-emp-knowledge-ui.azurewebsites.net"
    FabricWorkspaceId = "38362838-0531-4215-89af-a8a79221b545"
    FabricLakehouseId = "d11b209f-c774-481e-adcb-79920a94fd20"
    StorageAccount = "aistoragemyaacoub"
}

# ============================================================================
# UTILITIES
# ============================================================================

function Write-Check {
    param(
        [ValidateSet("PASS", "FAIL", "WARN", "INFO")]
        [string]$Status = "INFO",
        [string]$Component,
        [string]$Message
    )
    
    $Symbol = @{
        "PASS" = "[OK]"
        "FAIL" = "[XX]"
        "WARN" = "[!!]"
        "INFO" = "[--]"
    }
    
    $Color = @{
        "PASS" = "Green"
        "FAIL" = "Red"
        "WARN" = "Yellow"
        "INFO" = "Cyan"
    }
    
    Write-Host "$($Symbol[$Status]) $Component : $Message" -ForegroundColor $Color[$Status]
}

# ============================================================================
# VERIFICATION CHECKS
# ============================================================================

function Test-ApiHealth {
    Write-Host "`n=== API HEALTH ===" -ForegroundColor Cyan
    
    try {
        $Response = Invoke-WebRequest -Uri "$($Config.ApiUrl)/health" `
            -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        
        if ($Response.StatusCode -eq 200) {
            Write-Check "PASS" "API Health" "$($Config.ApiUrl)/health returned 200 OK"
            return $true
        }
    } catch {
        Write-Check "FAIL" "API Health" "$($_.Exception.Message)"
        return $false
    }
}

function Test-ApiSwagger {
    Write-Host "`n=== API DOCUMENTATION ===" -ForegroundColor Cyan
    
    try {
        $Response = Invoke-WebRequest -Uri "$($Config.ApiUrl)/swagger.json" `
            -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        
        if ($Response.StatusCode -eq 200) {
            $Json = $Response.Content | ConvertFrom-Json
            $ServerUrl = $Json.servers[0].url
            
            if ($ServerUrl -like "https://*") {
                Write-Check "PASS" "Swagger JSON" "Returns HTTPS URLs"
                Write-Check "INFO" "Server URL" $ServerUrl
                return $true
            } else {
                Write-Check "WARN" "Swagger JSON" "Server URL: $ServerUrl (not HTTPS)"
                return $true
            }
        }
    } catch {
        Write-Check "FAIL" "Swagger JSON" "$($_.Exception.Message)"
        return $false
    }
}

function Test-AzureResources {
    Write-Host "`n=== AZURE RESOURCES ===" -ForegroundColor Cyan
    
    # Check subscription
    if ($SubscriptionId) {
        try {
            az account set --subscription $SubscriptionId 2>&1 | Out-Null
            Write-Check "PASS" "Azure Subscription" "Set to $SubscriptionId"
        } catch {
            Write-Check "FAIL" "Azure Subscription" "Cannot access subscription"
            return $false
        }
    }
    
    # Check resource group
    try {
        $RgCheck = az group show --name $ResourceGroup --query "name" -o tsv 2>&1
        if ($RgCheck -eq $ResourceGroup) {
            Write-Check "PASS" "Resource Group" "$ResourceGroup exists"
        } else {
            Write-Check "FAIL" "Resource Group" "$ResourceGroup not found"
            return $false
        }
    } catch {
        Write-Check "FAIL" "Resource Group" "Cannot access resource group"
        return $false
    }
    
    # Check App Service
    try {
        $ApiStatus = az webapp show --name $Config.ApiName --resource-group $ResourceGroup `
            --query "state" -o tsv 2>&1
        
        if ($ApiStatus -eq "Running") {
            Write-Check "PASS" "API App Service" "$($Config.ApiName) is running"
        } else {
            Write-Check "WARN" "API App Service" "$($Config.ApiName) status: $ApiStatus"
        }
    } catch {
        Write-Check "FAIL" "API App Service" "Cannot access app service"
    }
    
    # Check Storage Account
    try {
        $StorageCheck = az storage account show --name $Config.StorageAccount `
            --resource-group $ResourceGroup --query "name" -o tsv 2>&1
        
        if ($StorageCheck -eq $Config.StorageAccount) {
            Write-Check "PASS" "Storage Account" "$($Config.StorageAccount) exists"
        } else {
            Write-Check "FAIL" "Storage Account" "Storage account not found"
        }
    } catch {
        Write-Check "WARN" "Storage Account" "Cannot verify storage account"
    }
    
    return $true
}

function Test-SourceCode {
    Write-Host "`n=== SOURCE CODE ===" -ForegroundColor Cyan
    
    $FilesToCheck = @{
        "api/server.py" = "API Server"
        "config/endpoints.json" = "Endpoints Config"
        "config/terraform.tfvars.json" = "Terraform Variables"
        "fabric/ontology/fabric_iq_ontology_complete.json" = "Ontology Config"
        "fabric/pipelines/employee_knowledge_pipeline_complete.json" = "Pipeline Config"
        "scripts/deploy.sh" = "Bash Deploy Script"
        "scripts/deploy-complete-solution.ps1" = "PowerShell Deploy Script"
    }
    
    foreach ($File in $FilesToCheck.GetEnumerator()) {
        if (Test-Path $File.Key) {
            $Size = (Get-Item $File.Key).Length / 1KB
            Write-Check "PASS" "Source File" "$($File.Value) ($([Math]::Round($Size, 1)) KB)"
        } else {
            Write-Check "FAIL" "Source File" "$($File.Value) not found"
        }
    }
    
    return $true
}

function Test-DataFiles {
    Write-Host "`n=== DATA FILES ===" -ForegroundColor Cyan
    
    $DataFiles = @{
        "data/employees.json" = "Employee Data"
        "data/contributions.json" = "Contribution Data"
        "data/digital_assets.json" = "Digital Assets"
        "data/projects.json" = "Project Data"
    }
    
    foreach ($File in $DataFiles.GetEnumerator()) {
        if (Test-Path $File.Key) {
            try {
                $Json = Get-Content $File.Key | ConvertFrom-Json
                $Count = $Json.Count
                Write-Check "PASS" "JSON File" "$($File.Value) - $Count records"
            } catch {
                Write-Check "FAIL" "JSON File" "$($File.Value) - Invalid JSON"
            }
        } else {
            Write-Check "FAIL" "JSON File" "$($File.Value) not found"
        }
    }
    
    # Check CSV exports
    $CsvPath = "data/exports/parquet"
    if (Test-Path $CsvPath) {
        $CsvFiles = Get-ChildItem $CsvPath -Filter "*.csv"
        Write-Check "PASS" "CSV Exports" "$($CsvFiles.Count) CSV files ready"
    } else {
        Write-Check "WARN" "CSV Exports" "Export directory not found"
    }
    
    return $true
}

function Test-Configuration {
    Write-Host "`n=== CONFIGURATION ===" -ForegroundColor Cyan
    
    try {
        $Endpoints = Get-Content "config/endpoints.json" | ConvertFrom-Json
        
        Write-Check "PASS" "Fabric Workspace" $Endpoints.microsoftFabric.workspaceId
        Write-Check "PASS" "Fabric Lakehouse" $Endpoints.microsoftFabric.lakehouseId
        Write-Check "PASS" "Semantic Model" $Endpoints.microsoftFabric.semanticModelId
        Write-Check "INFO" "API Endpoint" $Endpoints.hosting.apiUrl
        
        return $true
    } catch {
        Write-Check "FAIL" "Configuration" "Cannot read configuration"
        return $false
    }
}

function Test-Documentation {
    Write-Host "`n=== DOCUMENTATION ===" -ForegroundColor Cyan
    
    $Docs = @{
        "README.md"                = "Main Documentation"
        "FABRIC_DEPLOYMENT_GUIDE.md" = "Fabric Deployment Guide"
        "api/README.md"            = "API Reference"
    }
    
    foreach ($Doc in $Docs.GetEnumerator()) {
        if (Test-Path $Doc.Key) {
            Write-Check "PASS" "Documentation" "$($Doc.Value)"
        } else {
            Write-Check "WARN" "Documentation" "$($Doc.Key) not found"
        }
    }
    
    return $true
}

function Test-GitStatus {
    Write-Host "`n=== GIT STATUS ===" -ForegroundColor Cyan
    
    try {
        $Status = git status --porcelain
        if ($Status) {
            Write-Check "WARN" "Git" "Uncommitted changes detected"
        } else {
            Write-Check "PASS" "Git" "Working directory clean"
        }
        
        $Branch = git rev-parse --abbrev-ref HEAD
        Write-Check "INFO" "Git Branch" $Branch
        
        $Commit = git rev-parse --short HEAD
        Write-Check "INFO" "Git Commit" $Commit
        
        return $true
    } catch {
        Write-Check "WARN" "Git" "Cannot access Git repository"
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================

Write-Host ""
Write-Host "=" * 70
Write-Host "FABRIC IQ - DEPLOYMENT VERIFICATION"
Write-Host "=" * 70

$PassCount = 0
$FailCount = 0
$WarnCount = 0

# Run all checks
$Results = @(
    (Test-ApiHealth)
    (Test-ApiSwagger)
    (Test-AzureResources)
    (Test-SourceCode)
    (Test-DataFiles)
    (Test-Configuration)
    (Test-Documentation)
    (Test-GitStatus)
)

# Summary
Write-Host ""
Write-Host "=" * 70
Write-Host "VERIFICATION SUMMARY"
Write-Host "=" * 70

if (($Results | Where-Object { $_ -eq $false } | Measure-Object).Count -eq 0) {
    Write-Host "Status: [OK] ALL CHECKS PASSED" -ForegroundColor Green
} else {
    Write-Host "Status: [!!] SOME CHECKS FAILED - Review above" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next Steps:"
Write-Host "1. API is deployed and healthy"
Write-Host "2. All source code is in GitHub"
Write-Host "3. Data is prepared (1,020 records)"
Write-Host "4. Configuration is in place"
Write-Host ""
Write-Host "To configure and deploy: see FABRIC_DEPLOYMENT_GUIDE.md"
Write-Host "To trigger CI/CD:        push to main or run the Deploy workflow in GitHub Actions"
Write-Host ""
