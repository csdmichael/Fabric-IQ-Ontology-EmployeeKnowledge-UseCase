#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Microsoft Fabric components for the Fabric IQ Employee Knowledge solution.

.DESCRIPTION
    Uses the Fabric REST API (v1) with an Azure CLI access token to create or update:
      - Lakehouse
      - Ontology (via custom item or metadata upload)
      - Data Pipeline
      - Semantic Model
      - Power BI Reports (placeholder registration)
      - Dashboard

    Prerequisites:
      - Azure CLI (az) logged in with an identity that has Fabric workspace access
      - PowerShell 7+ or Windows PowerShell 5.1
      - Workspace must already exist (workspaceId from config/endpoints.json)

.PARAMETER WorkspaceId
    Fabric workspace GUID. Defaults to the value in config/endpoints.json.

.PARAMETER SkipLakehouse
    Skip lakehouse creation/verification (use if it already exists).

.PARAMETER SkipPipeline
    Skip pipeline creation.

.PARAMETER SkipSemanticModel
    Skip semantic model creation.

.PARAMETER SkipReports
    Skip Power BI report registration.

.EXAMPLE
    .\scripts\deploy-fabric-components.ps1
    .\scripts\deploy-fabric-components.ps1 -SkipLakehouse
#>

[CmdletBinding()]
param(
    [string]$WorkspaceId,
    [switch]$SkipLakehouse,
    [switch]$SkipPipeline,
    [switch]$SkipSemanticModel,
    [switch]$SkipReports,
    [switch]$SkipOntologyPublish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Helpers ───────────────────────────────────────────────────────────────────
function Write-Step([string]$Msg) { Write-Host "[->] $Msg" -ForegroundColor Cyan }
function Write-Ok  ([string]$Msg) { Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host "[!!] $Msg" -ForegroundColor Yellow }
function Write-Err ([string]$Msg) { Write-Host "[XX] $Msg" -ForegroundColor Red }
function Write-Info([string]$Msg) { Write-Host "     $Msg" -ForegroundColor Gray }

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$ConfigDir  = Join-Path $RepoRoot 'config'
$FabricDir  = Join-Path $RepoRoot 'fabric'
$DataDir    = Join-Path $RepoRoot 'data'
$ExportsDir = Join-Path $DataDir 'exports'

$FabricApiBase = 'https://api.fabric.microsoft.com/v1'
$PbiApiBase    = 'https://api.powerbi.com/v1.0/myorg'

# ── Load config ───────────────────────────────────────────────────────────────
Write-Step 'Loading configuration from config/endpoints.json...'
$endpoints = Get-Content (Join-Path $ConfigDir 'endpoints.json') -Raw | ConvertFrom-Json
$fabricCfg = $endpoints.microsoftFabric

if (-not $WorkspaceId) { $WorkspaceId = $fabricCfg.workspaceId }
$LakehouseId    = $fabricCfg.lakehouseId
$PipelineId     = $fabricCfg.pipelineId
$SemanticModelId= $fabricCfg.semanticModelId

Write-Ok "Workspace : $WorkspaceId"
Write-Ok "Lakehouse : $LakehouseId"

# ── Azure CLI check ───────────────────────────────────────────────────────────
Write-Step 'Verifying Azure CLI login...'
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Err 'Azure CLI not found. Install from https://aka.ms/installazurecliwindows'
    exit 1
}

$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Warn 'Not logged in. Running az login...'
    az login --output none
    $account = az account show | ConvertFrom-Json
}
Write-Ok "Logged in as: $($account.user.name) | Subscription: $($account.name)"

# ── Acquire Fabric access token ───────────────────────────────────────────────
Write-Step 'Acquiring Fabric API access token...'
$tokenJson = az account get-access-token --resource 'https://api.fabric.microsoft.com' 2>$null | ConvertFrom-Json
if (-not $tokenJson -or -not $tokenJson.accessToken) {
    Write-Warn 'Fabric token not available via az CLI. Trying PowerBI resource...'
    $tokenJson = az account get-access-token --resource 'https://analysis.windows.net/powerbi/api' | ConvertFrom-Json
}
$Token = $tokenJson.accessToken
Write-Ok 'Access token acquired'

function Invoke-FabricApi {
    param(
        [string]$Method = 'GET',
        [string]$Url,
        [object]$Body = $null,
        [switch]$AllowNotFound
    )
    $headers = @{
        'Authorization' = "Bearer $Token"
        'Content-Type'  = 'application/json'
    }
    $params = @{ Method = $Method; Uri = $Url; Headers = $headers; ErrorAction = 'Stop' }
    if ($Body) { $params['Body'] = ($Body | ConvertTo-Json -Depth 20 -Compress) }
    try {
        $response = Invoke-RestMethod @params
        return $response
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        if ($AllowNotFound -and $status -eq 404) { return $null }
        Write-Err "API call failed: $Method $Url"
        Write-Err $_.Exception.Message
        if ($_.ErrorDetails.Message) { Write-Info $_.ErrorDetails.Message }
        throw
    }
}

function Publish-OntologyEntities {
    param(
        [string]$WorkspaceId,
        [string]$OntologyId,
        [object]$OntologyDefinition
    )

    $tableEntities = @()
    foreach ($tableProp in $OntologyDefinition.tables.PSObject.Properties) {
        $tableName = $tableProp.Name
        $tableDef = $tableProp.Value
        $foreignKeys = @()
        if ($tableDef.PSObject.Properties.Name -contains "foreign_keys") {
            $foreignKeys = @($tableDef.foreign_keys)
        }
        $businessKey = $null
        if ($tableDef.PSObject.Properties.Name -contains "business_key") {
            $businessKey = $tableDef.business_key
        }
        $tableEntities += @{
            name = $tableName
            kind = "Table"
            attributes = @{
                columns = $tableDef.columns
                primaryKey = $tableDef.primary_key
                foreignKeys = $foreignKeys
                businessKey = $businessKey
            }
        }
    }

    $relationshipEntities = @()
    foreach ($rel in $OntologyDefinition.relationships) {
        $relationshipEntities += @{
            name = $rel.name
            kind = "Relationship"
            attributes = @{
                fromTable = $rel.from_table
                fromColumn = $rel.from_column
                toTable = $rel.to_table
                toColumn = $rel.to_column
                cardinality = $rel.cardinality
            }
        }
    }

    $payload = @{
        entities = @($tableEntities + $relationshipEntities)
        measures = $OntologyDefinition.measures
        metadata = @{
            workspaceId = $WorkspaceId
            ontologyId = $OntologyId
            source = "fabric/ontology/fabric_iq_ontology_complete.json"
            generatedAt = (Get-Date).ToString("o")
        }
    }

    $candidateCalls = @(
        @{ Method = "POST"; Url = "$FabricApiBase/workspaces/$WorkspaceId/ontologies/$OntologyId/entities:upsert" },
        @{ Method = "POST"; Url = "$FabricApiBase/workspaces/$WorkspaceId/ontologies/$OntologyId/entities" },
        @{ Method = "PUT"; Url = "$FabricApiBase/workspaces/$WorkspaceId/items/$OntologyId/definition" }
    )

    $errors = @()
    foreach ($call in $candidateCalls) {
        try {
            Invoke-FabricApi -Method $call.Method -Url $call.Url -Body $payload | Out-Null
            Write-Ok "Published ontology entities using endpoint: $($call.Url)"
            return
        } catch {
            $errors += "$($call.Method) $($call.Url) :: $($_.Exception.Message)"
        }
    }

    Write-Warn "Could not publish ontology entities via REST endpoints for this tenant/API version."
    Write-Info "Tried endpoints:"
    foreach ($e in $errors) {
        Write-Info "  $e"
    }
}

# ── 1. Verify Workspace ───────────────────────────────────────────────────────
Write-Step "Verifying workspace $WorkspaceId..."
$workspace = Invoke-FabricApi -Url "$FabricApiBase/workspaces/$WorkspaceId" -AllowNotFound
if (-not $workspace) {
    Write-Err "Workspace $WorkspaceId not found. Create it in the Fabric portal first."
    exit 1
}
Write-Ok "Workspace: $($workspace.displayName)"

# ── 2. Lakehouse ──────────────────────────────────────────────────────────────
if (-not $SkipLakehouse) {
    Write-Step 'Checking lakehouse...'
    $lh = Invoke-FabricApi -Url "$FabricApiBase/workspaces/$WorkspaceId/lakehouses/$LakehouseId" -AllowNotFound
    if ($lh) {
        Write-Ok "Lakehouse exists: $($lh.displayName) ($LakehouseId)"
    } else {
        Write-Warn "Lakehouse $LakehouseId not found. Creating..."
        $lhBody = @{
            displayName = 'EmployeeKnowledgeLakehouse'
            description = 'Fabric IQ employee knowledge data lake'
        }
        $created = Invoke-FabricApi -Method POST `
            -Url "$FabricApiBase/workspaces/$WorkspaceId/lakehouses" `
            -Body $lhBody
        $LakehouseId = $created.id
        Write-Ok "Lakehouse created: $LakehouseId"
        Write-Warn "Update microsoftFabric.lakehouseId in config/endpoints.json with: $LakehouseId"
    }

    # Upload CSV exports to OneLake if they exist
    $csvFiles = @(
        @{ name = 'employees';        file = 'employees.csv' },
        @{ name = 'contributions';    file = 'contributions.csv' },
        @{ name = 'digital_assets';   file = 'digital_assets.csv' },
        @{ name = 'projects';         file = 'projects.csv' }
    )

    Write-Step 'Checking for CSV exports to upload to OneLake...'
    $anyUploaded = $false
    foreach ($csv in $csvFiles) {
        $csvPath = Join-Path $ExportsDir $csv.file
        if (Test-Path $csvPath) {
            Write-Info "Found $($csv.file) - uploading to OneLake Tables/$($csv.name -replace '_','')..."
            # Use Azure Storage REST API for OneLake ABFS upload
            $oneLakePath = "Tables/$($csv.name -replace '_','')"
            $uploadUrl = "$FabricApiBase/workspaces/$WorkspaceId/lakehouses/$LakehouseId/tables/$($csv.name -replace '_','')/rows"
            Write-Warn "  OneLake file upload requires azcopy or OneLake SDK. Please manually upload $($csv.file) to $oneLakePath"
            $anyUploaded = $true
        } else {
            Write-Warn "CSV not found: $csvPath - run: python scripts/populate_fabric_complete.py"
        }
    }
    if (-not $anyUploaded) {
        Write-Warn 'No CSV exports found. Run populate_fabric_complete.py first to generate them.'
    }
}

# ── 3. Pipeline ───────────────────────────────────────────────────────────────
if (-not $SkipPipeline) {
    Write-Step 'Checking data pipeline...'
    $pipelineDef = Get-Content (Join-Path $FabricDir 'pipelines\employee_knowledge_pipeline_complete.json') -Raw | ConvertFrom-Json
    $pipeline = Invoke-FabricApi -Url "$FabricApiBase/workspaces/$WorkspaceId/dataPipelines/$PipelineId" -AllowNotFound
    if ($pipeline) {
        Write-Ok "Pipeline exists: $($pipeline.displayName) ($PipelineId)"
    } else {
        Write-Warn "Pipeline $PipelineId not found. Creating..."
        $pipelineBody = @{
            displayName = $pipelineDef.name
            description = $pipelineDef.description
        }
        try {
            $created = Invoke-FabricApi -Method POST `
                -Url "$FabricApiBase/workspaces/$WorkspaceId/dataPipelines" `
                -Body $pipelineBody
            Write-Ok "Pipeline created: $($created.id)"
            Write-Warn "Update microsoftFabric.pipelineId in config/endpoints.json with: $($created.id)"
        } catch {
            Write-Warn "Pipeline creation via REST not supported in this Fabric tier. Configure manually in Fabric portal."
            Write-Info "Pipeline definition: $($FabricDir)\pipelines\employee_knowledge_pipeline_complete.json"
        }
    }
}

# ── 4. Semantic Model ─────────────────────────────────────────────────────────
if (-not $SkipSemanticModel) {
    Write-Step 'Checking semantic model (Power BI dataset)...'
    # Use Power BI API for datasets (semantic models)
    $pbiToken = az account get-access-token --resource 'https://analysis.windows.net/powerbi/api' 2>$null | ConvertFrom-Json
    if ($pbiToken) {
        $pbiHeaders = @{
            'Authorization' = "Bearer $($pbiToken.accessToken)"
            'Content-Type'  = 'application/json'
        }
        $dsResponse = Invoke-RestMethod -Uri "$PbiApiBase/groups/$WorkspaceId/datasets" -Headers $pbiHeaders -ErrorAction SilentlyContinue
        $existingDs = $dsResponse.value | Where-Object { $_.id -eq $SemanticModelId }
        if ($existingDs) {
            Write-Ok "Semantic model exists: $($existingDs.name) ($SemanticModelId)"
        } else {
            $smDef = Get-Content (Join-Path $FabricDir 'semantic-model\employee_knowledge_semantic_model.json') -Raw | ConvertFrom-Json
            Write-Warn "Semantic model $SemanticModelId not found."
            Write-Info "To create, use Power BI Desktop (.pbix) or Tabular Editor with this definition:"
            Write-Info "  $FabricDir\semantic-model\employee_knowledge_semantic_model.json"
            Write-Info "Or import via Fabric portal: Data Engineering > New Semantic Model"
        }
    } else {
        Write-Warn 'Could not acquire Power BI token. Skipping semantic model check.'
    }
}

# ── 5. Power BI Reports ───────────────────────────────────────────────────────
if (-not $SkipReports) {
    Write-Step 'Checking Power BI reports...'
    $reportsJson = Get-Content (Join-Path $FabricDir 'powerbi\powerbi_reports.json') -Raw | ConvertFrom-Json
    $pbiToken2 = az account get-access-token --resource 'https://analysis.windows.net/powerbi/api' 2>$null | ConvertFrom-Json
    if (-not $pbiToken2) {
        Write-Warn 'Cannot acquire Power BI token - skipping report verification'
    } else {
        $pbiHeaders2 = @{
            'Authorization' = "Bearer $($pbiToken2.accessToken)"
            'Content-Type'  = 'application/json'
        }
        try {
            $existingReports = Invoke-RestMethod -Uri "$PbiApiBase/groups/$WorkspaceId/reports" -Headers $pbiHeaders2 -ErrorAction Stop
            $existingNames   = $existingReports.value | ForEach-Object { $_.name }
            foreach ($rpt in $reportsJson) {
                if ($existingNames -contains $rpt.name) {
                    Write-Ok "  Report exists: $($rpt.name)"
                } else {
                    Write-Warn "  Report not found: $($rpt.name)"
                    Write-Info "  -> Create in Fabric portal using dataset: $($rpt.datasetId)"
                    Write-Info "  -> Tags: $($rpt.tags -join ', ')"
                }
            }
        } catch {
            Write-Warn "Could not list reports: $($_.Exception.Message)"
            Write-Info "Verify reports manually in Power BI workspace: $WorkspaceId"
        }
    }

    # Print dashboard summary
    $dashboardFile = Join-Path $FabricDir 'powerbi\employee_knowledge_dashboards.json'
    if (Test-Path $dashboardFile) {
        $dashDef = Get-Content $dashboardFile -Raw | ConvertFrom-Json
        Write-Info "Dashboard definition available: $dashboardFile"
        Write-Warn 'Dashboards must be created manually in the Power BI service by pinning visuals from reports.'
    }
}

# ── 6. Ontology ───────────────────────────────────────────────────────────────
Write-Step 'Checking ontology item...'
$ontologyId = $fabricCfg.ontologyId
$ontologyDef = Get-Content (Join-Path $FabricDir 'ontology\fabric_iq_ontology_complete.json') -Raw | ConvertFrom-Json

# Try to GET the ontology item (Fabric custom item type may vary)
$ontologyItem = Invoke-FabricApi -Url "$FabricApiBase/workspaces/$WorkspaceId/items/$ontologyId" -AllowNotFound
if ($ontologyItem) {
    Write-Ok "Ontology item exists: $($ontologyItem.displayName) ($ontologyId)"
    if (-not $SkipOntologyPublish) {
        Write-Step 'Publishing ontology entities from fabric/ontology/fabric_iq_ontology_complete.json...'
        Publish-OntologyEntities -WorkspaceId $WorkspaceId -OntologyId $ontologyId -OntologyDefinition $ontologyDef
    }
} else {
    Write-Warn "Ontology item $ontologyId not found in workspace."
    Write-Info "The ontology definition is at: $FabricDir\ontology\fabric_iq_ontology_complete.json"
    Write-Info "Tables defined: $($ontologyDef.tables.PSObject.Properties.Name -join ', ')"
    Write-Info "To configure, create a Lakehouse schema in the Fabric portal matching these tables."
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '═══════════════════════════════════════════════════════' -ForegroundColor Magenta
Write-Host ' Fabric IQ Deployment Summary' -ForegroundColor Magenta
Write-Host '═══════════════════════════════════════════════════════' -ForegroundColor Magenta
Write-Host "  Workspace ID    : $WorkspaceId"
Write-Host "  Lakehouse ID    : $LakehouseId"
Write-Host "  Semantic Model  : $SemanticModelId"
Write-Host "  Pipeline ID     : $PipelineId"
Write-Host ''
Write-Host '  Fabric Portal   : https://app.fabric.microsoft.com/groups/' -NoNewline
Write-Host $WorkspaceId -ForegroundColor Cyan
Write-Host '  Power BI Portal : https://app.powerbi.com/groups/' -NoNewline
Write-Host $WorkspaceId -ForegroundColor Cyan
Write-Host ''
Write-Host '  Manual steps still required:' -ForegroundColor Yellow
Write-Host '    1. Upload CSV exports to OneLake Tables (use azcopy or Fabric portal)'
Write-Host '    2. Configure semantic model relationships in Power BI Desktop'
Write-Host '    3. Create Power BI reports and pin visuals to dashboard'
Write-Host '    4. Set refresh schedule on semantic model'
Write-Host '═══════════════════════════════════════════════════════' -ForegroundColor Magenta
