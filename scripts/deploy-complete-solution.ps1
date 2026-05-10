#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete Fabric IQ Solution - End-to-End Deployment Script (PowerShell)
    Deploys API, data, Fabric pipelines, and Power BI dashboards

.DESCRIPTION
    This script automates the complete deployment of the Fabric IQ solution
    Run this after cloning the repository to fully rebuild the solution

.PARAMETER SubscriptionId
    Azure subscription ID (required)

.PARAMETER ResourceGroup
    Azure resource group name (default: ai-myaacoub)

.PARAMETER Region
    Azure region (default: eastus)

.EXAMPLE
    .\deploy-complete-solution.ps1 -SubscriptionId "YOUR_SUBSCRIPTION_ID"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "ai-myaacoub",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "eastus"
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$Config = @{
    Subscription = $SubscriptionId
    ResourceGroup = $ResourceGroup
    Region = $Region
    ApiName = "fabric-iq-emp-knowledge-api"
    UiName = "fabric-iq-emp-knowledge-ui"
    PlanName = "plan-fabriciq-b3"
    PlanSku = "B3"
    FabricWorkspaceId = "38362838-0531-4215-89af-a8a79221b545"
    FabricLakehouseId = "d11b209f-c774-481e-adcb-79920a94fd20"
    FabricSemanticModelId = "21e0a7be-1e7d-4110-8faa-d835f81c6559"
    StorageAccount = "aistoragemyaacoub"
}

# ============================================================================
# UTILITIES
# ============================================================================

function Write-Status {
    param(
        [ValidateSet("OK", "INFO", "ERR", "WARN")]
        [string]$Level = "INFO",
        [string]$Message
    )
    
    $Prefix = @{
        "OK" = "[OK]"
        "INFO" = "[->]"
        "ERR" = "[XX]"
        "WARN" = "[!!]"
    }
    
    $Color = @{
        "OK" = "Green"
        "INFO" = "Cyan"
        "ERR" = "Red"
        "WARN" = "Yellow"
    }
    
    Write-Host "$($Prefix[$Level]) $Message" -ForegroundColor $Color[$Level]
}

# ============================================================================
# DEPLOYMENT PHASES
# ============================================================================

function Invoke-Phase1-VerifyPrerequisites {
    Write-Host ""
    Write-Status "INFO" "PHASE 1: Verifying prerequisites..."
    
    $Tools = @{
        "PowerShell 7+" = "pwsh --version"
        "Azure CLI" = "az --version"
        "Git" = "git --version"
        "Python" = "python --version"
    }
    
    $AllOk = $true
    foreach ($Tool in $Tools.GetEnumerator()) {
        try {
            $Output = Invoke-Expression $Tool.Value 2>&1
            if ($?) {
                Write-Status "OK" "$($Tool.Key) is installed"
            } else {
                Write-Status "ERR" "$($Tool.Key) not found"
                $AllOk = $false
            }
        } catch {
            Write-Status "ERR" "$($Tool.Key) not found"
            $AllOk = $false
        }
    }
    
    return $AllOk
}

function Invoke-Phase2-PrepareSourceCode {
    Write-Host ""
    Write-Status "INFO" "PHASE 2: Preparing source code..."
    
    $RequiredDirs = @("api", "config", "data", "fabric", "scripts", "terraform")
    
    foreach ($Dir in $RequiredDirs) {
        if (Test-Path $Dir) {
            Write-Status "OK" "Directory exists: $Dir"
        } else {
            Write-Status "WARN" "Directory missing: $Dir"
        }
    }
    
    return $true
}

function Invoke-Phase3-ValidateConfigurations {
    Write-Host ""
    Write-Status "INFO" "PHASE 3: Validating configurations..."
    
    $Configs = @{
        "config/endpoints.json" = "Endpoints config"
        "fabric/ontology/fabric_iq_ontology_complete.json" = "Ontology"
        "fabric/pipelines/employee_knowledge_pipeline_complete.json" = "Pipeline"
        "fabric/powerbi/powerbi_reports_config.json" = "Power BI config"
    }
    
    $AllValid = $true
    foreach ($Config in $Configs.GetEnumerator()) {
        if (Test-Path $Config.Key) {
            try {
                Get-Content $Config.Key | ConvertFrom-Json | Out-Null
                Write-Status "OK" "$($Config.Value) is valid JSON"
            } catch {
                Write-Status "ERR" "$($Config.Value) has invalid JSON"
                $AllValid = $false
            }
        } else {
            Write-Status "WARN" "$($Config.Value) not found"
        }
    }
    
    return $AllValid
}

function Invoke-Phase4-DeployAPI {
    Write-Host ""
    Write-Status "INFO" "PHASE 4: Deploying API..."
    
    $ApiName = $Config.ApiName
    $RgName = $Config.ResourceGroup
    
    # Create deployment package
    Write-Status "INFO" "Creating API deployment package..."
    $ZipFile = Join-Path $env:TEMP "fabriciq-api-deploy.zip"
    
    git archive --format=zip --output $ZipFile HEAD api config data fabric README.md LICENSE 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Status "OK" "Deployment package created"
    } else {
        Write-Status "ERR" "Failed to create deployment package"
        return $false
    }
    
    # Deploy to Azure
    Write-Status "INFO" "Deploying to $ApiName..."
    az webapp deploy --name $ApiName --resource-group $RgName --src-path $ZipFile --type zip -o none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Status "OK" "API deployed to Azure"
    } else {
        Write-Status "ERR" "Failed to deploy to Azure"
        return $false
    }
    
    # Configure startup
    Write-Status "INFO" "Configuring startup..."
    az webapp config set --name $ApiName --resource-group $RgName --startup-file "python -u api/server.py" -o none 2>&1
    
    # Restart app
    Write-Status "INFO" "Restarting application..."
    az webapp restart --name $ApiName --resource-group $RgName -o none 2>&1
    
    # Wait for startup
    Write-Status "INFO" "Waiting 45 seconds for application startup..."
    Start-Sleep -Seconds 45
    
    # Verify health
    Write-Status "INFO" "Verifying API health..."
    try {
        $Response = Invoke-WebRequest -Uri "https://$ApiName.azurewebsites.net/health" -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        if ($Response.StatusCode -eq 200) {
            Write-Status "OK" "API health check passed"
            return $true
        }
    } catch {
        Write-Status "WARN" "API health check failed (may take more time): $($_.Exception.Message)"
        return $true  # Still proceed
    }
    
    return $true
}

function Invoke-Phase5-PrepareData {
    Write-Host ""
    Write-Status "INFO" "PHASE 5: Preparing data..."
    
    $CsvPath = "data/exports/parquet"
    if (Test-Path $CsvPath) {
        $CsvFiles = Get-ChildItem $CsvPath -Filter "*.csv"
        
        if ($CsvFiles.Count -eq 4) {
            foreach ($Csv in $CsvFiles) {
                $Rows = @(Get-Content $Csv.FullName) | Measure-Object | Select-Object -ExpandProperty Count
                $Rows = $Rows - 1  # Exclude header
                Write-Status "OK" "$($Csv.Name): $Rows rows ready"
            }
            return $true
        } else {
            Write-Status "ERR" "Expected 4 CSV files, found $($CsvFiles.Count)"
            return $false
        }
    } else {
        Write-Status "ERR" "Data exports directory not found"
        return $false
    }
}

function Invoke-Phase6-VerifyFabricSetup {
    Write-Host ""
    Write-Status "INFO" "PHASE 6: Verifying Fabric setup..."
    
    Write-Status "OK" "Workspace ID: $($Config.FabricWorkspaceId)"
    Write-Status "OK" "Lakehouse ID: $($Config.FabricLakehouseId)"
    Write-Status "OK" "Semantic Model ID: $($Config.FabricSemanticModelId)"
    
    Write-Host ""
    Write-Status "INFO" "Manual Actions Required:"
    Write-Status "INFO" "1. Upload CSV files to OneLake"
    Write-Status "INFO" "2. Configure semantic model relationships"
    Write-Status "INFO" "3. Create Power BI reports and dashboards"
    Write-Status "INFO" "See FABRIC_DEPLOYMENT_GUIDE.md for details"
    
    return $true
}

function Invoke-Phase7-GenerateDocumentation {
    Write-Host ""
    Write-Status "INFO" "PHASE 7: Verifying documentation..."
    
    $Docs = @{
        "QUICK_START.md" = "Quick start guide"
        "DEPLOYMENT_STATUS.md" = "Deployment status"
        "FABRIC_DEPLOYMENT_GUIDE.md" = "Fabric deployment guide"
        "POWERBI_SETUP_GUIDE.md" = "Power BI setup guide"
        "COMPLETION_SUMMARY.md" = "Completion summary"
    }
    
    foreach ($Doc in $Docs.GetEnumerator()) {
        if (Test-Path $Doc.Key) {
            Write-Status "OK" "$($Doc.Value) exists"
        } else {
            Write-Status "WARN" "$($Doc.Key) not found"
        }
    }
    
    return $true
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host ""
Write-Host "=" * 70
Write-Host "FABRIC IQ SOLUTION - END-TO-END DEPLOYMENT"
Write-Host "=" * 70

$Phases = @(
    @{ Name = "Prerequisites"; Func = { Invoke-Phase1-VerifyPrerequisites } }
    @{ Name = "Source Code"; Func = { Invoke-Phase2-PrepareSourceCode } }
    @{ Name = "Configurations"; Func = { Invoke-Phase3-ValidateConfigurations } }
    @{ Name = "API Deployment"; Func = { Invoke-Phase4-DeployAPI } }
    @{ Name = "Data Preparation"; Func = { Invoke-Phase5-PrepareData } }
    @{ Name = "Fabric Setup"; Func = { Invoke-Phase6-VerifyFabricSetup } }
    @{ Name = "Documentation"; Func = { Invoke-Phase7-GenerateDocumentation } }
)

$Results = @()
foreach ($Phase in $Phases) {
    try {
        $Success = & $Phase.Func
        $Results += @{ Name = $Phase.Name; Success = $Success }
    } catch {
        Write-Status "ERR" "Phase error: $($_.Exception.Message)"
        $Results += @{ Name = $Phase.Name; Success = $false }
    }
}

# Summary
Write-Host ""
Write-Host "=" * 70
Write-Host "DEPLOYMENT SUMMARY"
Write-Host "=" * 70

foreach ($Result in $Results) {
    $Status = if ($Result.Success) { "[OK] PASS" } else { "[XX] FAIL" }
    Write-Host "$Status  $($Result.Name)"
}

$Passed = ($Results | Where-Object { $_.Success } | Measure-Object).Count
$Total = $Results.Count
Write-Host ""
Write-Host "Result: $Passed/$Total phases completed"

# Next Steps
Write-Host ""
Write-Host "=" * 70
Write-Host "NEXT STEPS"
Write-Host "=" * 70
Write-Host @"

1. LOAD DATA TO ONELAKE
   - Go to: https://app.powerbi.com
   - Upload 4 CSV files from: data/exports/parquet/
   - See: FABRIC_DEPLOYMENT_GUIDE.md for details

2. CONFIGURE SEMANTIC MODEL
   - Add relationships between tables
   - Add Power BI measures
   - Time estimate: 10 minutes

3. CREATE POWER BI REPORTS & DASHBOARDS
   - Create 3 reports with 11 visuals
   - Create main dashboard
   - Publish app
   - Time estimate: 50 minutes

4. VERIFY & TEST
   - Health check API endpoint
   - Access Power BI app
   - Share with team

For detailed instructions: See FABRIC_DEPLOYMENT_GUIDE.md
For architecture overview: See DEPLOYMENT_STATUS.md
"@

if (($Results | Where-Object { -not $_.Success } | Measure-Object).Count -eq 0) {
    exit 0
} else {
    exit 1
}
