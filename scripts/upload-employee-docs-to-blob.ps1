#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Upload employee documents from data/employees to Azure Blob Storage using config values.

.DESCRIPTION
    Reads subscription, resource group, storage endpoint, and target container from config files:
      - config/azure-hosting-resources.json
      - config/endpoints.json
      - config/service-config.json

.PARAMETER SourcePath
    Local source path containing employee document folders.

.PARAMETER TemporarilyAllowPublicAccess
    Temporarily sets storage firewall default action to Allow for this upload, then restores it to Deny.
#>

[CmdletBinding()]
param(
    [string]$SourcePath = "data/employees",
    [switch]$TemporarilyAllowPublicAccess
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$hostingCfgPath = Join-Path $repoRoot "config/azure-hosting-resources.json"
$endpointsPath = Join-Path $repoRoot "config/endpoints.json"
$serviceCfgPath = Join-Path $repoRoot "config/service-config.json"

foreach ($path in @($hostingCfgPath, $endpointsPath, $serviceCfgPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing required config file: $path"
    }
}

$hostingCfg = Get-Content $hostingCfgPath -Raw | ConvertFrom-Json
$endpoints = Get-Content $endpointsPath -Raw | ConvertFrom-Json
$serviceCfg = Get-Content $serviceCfgPath -Raw | ConvertFrom-Json

$subscriptionId = $hostingCfg.subscriptionId
$resourceGroup = $hostingCfg.resourceGroup
$blobEndpoint = $endpoints.azure.blobStorageEndpoint
$containerName = $serviceCfg.documentIntelligence.storageContainer

if (-not $subscriptionId) { throw "Missing subscriptionId in config/azure-hosting-resources.json" }
if (-not $resourceGroup) { throw "Missing resourceGroup in config/azure-hosting-resources.json" }
if (-not $blobEndpoint) { throw "Missing azure.blobStorageEndpoint in config/endpoints.json" }
if (-not $containerName) { throw "Missing documentIntelligence.storageContainer in config/service-config.json" }

$storageAccount = ([Uri]$blobEndpoint).Host.Split('.')[0]
$fullSourcePath = Join-Path $repoRoot $SourcePath
if (-not (Test-Path $fullSourcePath)) {
    throw "Source path not found: $fullSourcePath"
}

az account set --subscription $subscriptionId --only-show-errors | Out-Null

$restoreDeny = $false
try {
    if ($TemporarilyAllowPublicAccess) {
        az storage account update --name $storageAccount --resource-group $resourceGroup --default-action Allow --public-network-access Enabled --only-show-errors --output none
        $restoreDeny = $true
    }

    az storage blob upload-batch --account-name $storageAccount --destination $containerName --source $fullSourcePath --auth-mode login --overwrite --no-progress --output none

    $items = az storage blob list --account-name $storageAccount --container-name $containerName --auth-mode login -o json | ConvertFrom-Json
    Write-Host "Upload complete. Blob count in $containerName: $($items.Count)" -ForegroundColor Green
} finally {
    if ($restoreDeny) {
        az storage account update --name $storageAccount --resource-group $resourceGroup --default-action Deny --public-network-access Enabled --only-show-errors --output none
        Write-Host "Storage firewall restored to default-action Deny." -ForegroundColor Yellow
    }
}
