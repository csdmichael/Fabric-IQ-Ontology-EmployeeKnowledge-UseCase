param(
	[int]$MaxDocs = 300
)

$ErrorActionPreference = 'Stop'

$hosting = Get-Content "config/azure-hosting-resources.json" -Raw | ConvertFrom-Json
$serviceConfig = Get-Content "config/service-config.json" -Raw | ConvertFrom-Json
$endpoints = Get-Content "config/endpoints.json" -Raw | ConvertFrom-Json

$subscriptionId = $hosting.subscriptionId
$resourceGroup = $hosting.resourceGroup

if (-not $subscriptionId) { throw 'Missing subscriptionId in config/azure-hosting-resources.json' }
if (-not $resourceGroup) { throw 'Missing resourceGroup in config/azure-hosting-resources.json' }

az account set --subscription $subscriptionId --only-show-errors | Out-Null

$storageEndpoint = $endpoints.azure.blobStorageEndpoint
if (-not $storageEndpoint) { throw 'Missing azure.blobStorageEndpoint in config/endpoints.json' }
$storageAccount = ([Uri]$storageEndpoint).Host.Split('.')[0]

$cosmosEndpoint = $serviceConfig.cosmosDb.endpoint
if (-not $cosmosEndpoint) { throw 'Missing cosmosDb.endpoint in config/service-config.json' }
$cosmosAccount = ([Uri]$cosmosEndpoint).Host.Split('.')[0]

$searchEndpoint = $serviceConfig.aiSearch.endpoint
if (-not $searchEndpoint) { throw 'Missing aiSearch.endpoint in config/service-config.json' }
$searchService = ([Uri]$searchEndpoint).Host.Split('.')[0]

Write-Host 'Fetching Azure keys...'
$env:AZ_STORAGE_KEY = az storage account keys list --resource-group $resourceGroup --account-name $storageAccount --query "[0].value" -o tsv
$env:AZ_COSMOS_KEY = az cosmosdb keys list --resource-group $resourceGroup --name $cosmosAccount --query "primaryMasterKey" -o tsv
$env:AZ_SEARCH_ADMIN_KEY = az search admin-key show --resource-group $resourceGroup --service-name $searchService --query "primaryKey" -o tsv

if (-not $env:AZ_STORAGE_KEY) { throw 'Failed to fetch storage key' }
if (-not $env:AZ_COSMOS_KEY) { throw 'Failed to fetch cosmos key' }
if (-not $env:AZ_SEARCH_ADMIN_KEY) { throw 'Failed to fetch search admin key' }

$env:AZ_STORAGE_ACCOUNT = $storageAccount
$env:AZ_STORAGE_ACCOUNT_URL = $endpoints.azure.blobStorageEndpoint
$env:AZ_SEARCH_JSON_INDEX = $serviceConfig.aiSearch.jsonIndexName
$env:AZ_SEARCH_DOC_INDEX = $serviceConfig.aiSearch.docIndexName

$containerName = $serviceConfig.documentIntelligence.storageContainer
Write-Host "Ensuring blob container exists: $containerName"
az storage container create --auth-mode login --account-name $env:AZ_STORAGE_ACCOUNT --name $containerName --only-show-errors | Out-Null

Write-Host "Running deploy_ai_data_pipeline.py with --max-docs $MaxDocs ..."
python scripts/deploy_ai_data_pipeline.py --max-docs $MaxDocs
