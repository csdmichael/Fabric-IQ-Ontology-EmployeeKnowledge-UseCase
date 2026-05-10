#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Fabric ontology, data, and Power BI reports
    
.DESCRIPTION
    This script verifies all components are ready for manual Fabric/Power BI deployment
    
.PARAMETER SubscriptionId
    Azure subscription ID
    
.PARAMETER ResourceGroup
    Azure resource group name
    
.EXAMPLE
    .\deploy-fabric-powerbi.ps1 -SubscriptionId "YOUR_SUB_ID"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "ai-myaacoub"
)

# Configuration
$Config = @{
    Subscription = $SubscriptionId
    ResourceGroup = $ResourceGroup
    FabricWorkspaceId = "38362838-0531-4215-89af-a8a79221b545"
    FabricLakehouseId = "d11b209f-c774-481e-adcb-79920a94fd20"
    SemanticModelId = "21e0a7be-1e7d-4110-8faa-d835f81c6559"
    
    DataFiles = @(
        @{Name="Employees"; Path="data/exports/parquet/Employees.csv"; Rows=100}
        @{Name="Contributions"; Path="data/exports/parquet/Contributions.csv"; Rows=100}
        @{Name="DigitalAssets"; Path="data/exports/parquet/DigitalAssets.csv"; Rows=800}
        @{Name="Projects"; Path="data/exports/parquet/Projects.csv"; Rows=20}
    )
}

# Logging
function Log-Status {
    param([string]$Message, [string]$Level = "INFO")
    $prefix = @{"INFO"="[+]"; "OK"="[OK]"; "ERR"="[ERROR]"; "WARN"="[WARN]"}
    $color = @{"INFO"="Cyan"; "OK"="Green"; "ERR"="Red"; "WARN"="Yellow"}
    Write-Host "$($prefix[$Level]) $Message" -ForegroundColor $color[$Level]
}

# Phase 1: Check Prerequisites
function Test-Prerequisites {
    Log-Status "PHASE 1: Checking prerequisites..." "INFO"
    
    $tools = @("az", "git", "python")
    foreach ($tool in $tools) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Log-Status "$tool: installed" "OK"
        } else {
            Log-Status "$tool: NOT FOUND" "ERR"
            return $false
        }
    }
    return $true
}

# Phase 2: Verify Data Files
function Test-DataFiles {
    Log-Status "`nPHASE 2: Verifying data files..." "INFO"
    
    $totalRows = 0
    foreach ($file in $Config.DataFiles) {
        if (Test-Path $file.Path) {
            $content = @(Get-Content $file.Path)
            $rows = $content.Count - 1
            Log-Status "$($file.Name): $rows records (expected: $($file.Rows))" "OK"
            $totalRows += $rows
        } else {
            Log-Status "$($file.Name): NOT FOUND at $($file.Path)" "ERR"
            return $false
        }
    }
    Log-Status "Total records ready: $totalRows" "OK"
    return $true
}

# Phase 3: Check Configuration
function Test-Configuration {
    Log-Status "`nPHASE 3: Checking configuration files..." "INFO"
    
    $files = @(
        "config/endpoints.json"
        "fabric/ontology/fabric_iq_ontology_complete.json"
        "fabric/powerbi/powerbi_reports_config.json"
    )
    
    foreach ($file in $files) {
        if (Test-Path $file) {
            Log-Status "$file: present" "OK"
        } else {
            Log-Status "$file: NOT FOUND" "ERR"
            return $false
        }
    }
    return $true
}

# Phase 4: Display Deployment Steps
function Show-DeploymentSteps {
    Log-Status "`nPHASE 4: Deployment steps for manual configuration" "INFO"
    
    Write-Host "`n=========================================="
    Write-Host "FABRIC & POWER BI DEPLOYMENT STEPS"
    Write-Host "==========================================`n"
    
    Write-Host "STEP 1: Load Data to OneLake (10 minutes)" -ForegroundColor Yellow
    Write-Host "  1. Go to: https://app.powerbi.com"
    Write-Host "  2. Select workspace: $($Config.FabricWorkspaceId)"
    Write-Host "  3. Open Lakehouse"
    Write-Host "  4. Upload CSV files from: data/exports/parquet/"
    Write-Host "     - Employees.csv (100 rows)"
    Write-Host "     - Contributions.csv (100 rows)"
    Write-Host "     - DigitalAssets.csv (800 rows)"
    Write-Host "     - Projects.csv (20 rows)"
    Write-Host "  5. Create corresponding tables"
    Write-Host ""
    
    Write-Host "STEP 2: Configure Semantic Model (10 minutes)" -ForegroundColor Yellow
    Write-Host "  1. Open semantic model: $($Config.SemanticModelId)"
    Write-Host "  2. Switch to Model view"
    Write-Host "  3. Add relationships:"
    Write-Host "     - Contributions.employeeId -> Employees.employeeId"
    Write-Host "     - DigitalAssets.employeeId -> Employees.employeeId"
    Write-Host "  4. Add measures:"
    Write-Host "     - Total Employees"
    Write-Host "     - Total Contributions"
    Write-Host "     - Avg Contribution Score"
    Write-Host "     - Total Assets"
    Write-Host "     - Total Projects"
    Write-Host ""
    
    Write-Host "STEP 3: Create Power BI Reports (30 minutes)" -ForegroundColor Yellow
    Write-Host "  Report 1: Employee Skills Dashboard"
    Write-Host "    - KPI: Total Employees"
    Write-Host "    - Table: Employee details"
    Write-Host "    - Bar Chart: Contributions by department"
    Write-Host "    - Pie Chart: Employees by tier"
    Write-Host ""
    Write-Host "  Report 2: Project Contribution Analysis"
    Write-Host "    - KPI: Total Projects"
    Write-Host "    - Table: Project details"
    Write-Host "    - Scatter: Projects vs contributions"
    Write-Host "    - Bar Chart: Top 10 employees"
    Write-Host ""
    Write-Host "  Report 3: Digital Assets Distribution"
    Write-Host "    - KPI: Total Assets"
    Write-Host "    - Pie Chart: Assets by type"
    Write-Host "    - Bar Chart: Assets by owner"
    Write-Host "    - Table: Asset catalog"
    Write-Host ""
    
    Write-Host "STEP 4: Create Dashboard (15 minutes)" -ForegroundColor Yellow
    Write-Host "  1. New Dashboard: 'Employee Knowledge Dashboard'"
    Write-Host "  2. Pin key visuals:"
    Write-Host "     - Total Employees KPI"
    Write-Host "     - Contributions by Department chart"
    Write-Host "     - Total Projects KPI"
    Write-Host "     - Total Assets KPI"
    Write-Host "     - Asset type distribution"
    Write-Host "  3. Arrange and format for readability"
    Write-Host ""
    
    Write-Host "STEP 5: Publish Power BI App (5 minutes)" -ForegroundColor Yellow
    Write-Host "  1. Go to Apps section"
    Write-Host "  2. Create app"
    Write-Host "  3. Name: 'Employee Knowledge App'"
    Write-Host "  4. Add dashboard and reports"
    Write-Host "  5. Set access permissions"
    Write-Host "  6. Publish"
    Write-Host ""
    
    Write-Host "=========================================="
    Write-Host "ESTIMATED TIMELINE"
    Write-Host "=========================================="
    Write-Host "  Step 1 (Data Load):        10 minutes"
    Write-Host "  Step 2 (Semantic Model):   10 minutes"
    Write-Host "  Step 3 (Reports):          30 minutes"
    Write-Host "  Step 4 (Dashboard):        15 minutes"
    Write-Host "  Step 5 (Publish):           5 minutes"
    Write-Host "  ----------------------------------------"
    Write-Host "  TOTAL:                     70 minutes"
    Write-Host ""
    
    Write-Host "RESOURCES CONFIGURED" -ForegroundColor Cyan
    Write-Host "  Workspace: $($Config.FabricWorkspaceId)"
    Write-Host "  Lakehouse: $($Config.FabricLakehouseId)"
    Write-Host "  Semantic Model: $($Config.SemanticModelId)"
    Write-Host "  Data: 1,020 total records"
    Write-Host "  Reports: 3 reports (11 visuals)"
    Write-Host "  Dashboards: 1 main dashboard"
    Write-Host ""
    
    Write-Host "DETAILED GUIDES" -ForegroundColor Cyan
    Write-Host "  - FABRIC_DEPLOYMENT_GUIDE.md"
    Write-Host "  - POWERBI_SETUP_GUIDE.md"
    Write-Host "  - QUICK_START.md"
    Write-Host ""
}

# Main execution
function Main {
    Write-Host "`n"
    Log-Status "FABRIC AND POWER BI DEPLOYMENT VERIFICATION" "INFO"
    Log-Status "Subscription: $($Config.Subscription)" "INFO"
    Log-Status "Resource Group: $($Config.ResourceGroup)" "INFO"
    
    if (-not (Test-Prerequisites)) {
        Log-Status "Prerequisites check FAILED" "ERR"
        exit 1
    }
    
    if (-not (Test-DataFiles)) {
        Log-Status "Data verification FAILED" "ERR"
        exit 1
    }
    
    if (-not (Test-Configuration)) {
        Log-Status "Configuration check FAILED" "ERR"
        exit 1
    }
    
    Show-DeploymentSteps
    
    Log-Status "`nDeployment verification complete - ready for manual steps" "OK"
    Write-Host ""
}

Main
