param(
	[int]$MaxDocs = 300
)

$ErrorActionPreference = 'Stop'

Write-Host 'Fetching Azure keys...'
$env:AZ_STORAGE_KEY = az storage account keys list --resource-group ai-myaacoub --account-name aistoragemyaacoub --query "[0].value" -o tsv
$env:AZ_COSMOS_KEY = az cosmosdb keys list --resource-group ai-myaacoub --name cosmos-ai-poc --query "primaryMasterKey" -o tsv
$env:AZ_SEARCH_ADMIN_KEY = az search admin-key show --resource-group ai-myaacoub --service-name aisearch-poc-myaacoub --query "primaryKey" -o tsv

if (-not $env:AZ_STORAGE_KEY) { throw 'Failed to fetch storage key' }
if (-not $env:AZ_COSMOS_KEY) { throw 'Failed to fetch cosmos key' }
if (-not $env:AZ_SEARCH_ADMIN_KEY) { throw 'Failed to fetch search admin key' }

$env:AZ_STORAGE_ACCOUNT = 'aistoragemyaacoub'
$env:AZ_SEARCH_JSON_INDEX = 'employee-knowledge-json-index'
$env:AZ_SEARCH_DOC_INDEX = 'employee-knowledge-doc-index'

$serviceConfig = Get-Content "config/service-config.json" -Raw | ConvertFrom-Json
$containerName = $serviceConfig.documentIntelligence.storageContainer
Write-Host "Ensuring blob container exists: $containerName"
az storage container create --auth-mode login --account-name $env:AZ_STORAGE_ACCOUNT --name $containerName --only-show-errors | Out-Null

Write-Host "Running deploy_ai_data_pipeline.py with --max-docs $MaxDocs ..."
python scripts/deploy_ai_data_pipeline.py --max-docs $MaxDocs
