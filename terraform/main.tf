# ── Existing Resource Group (ai-myaacoub) ──────────────────────────────────
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# ── Storage Account ────────────────────────────────────────────────────────
resource "azurerm_storage_account" "main" {
  name                          = var.storage_account_name
  resource_group_name           = data.azurerm_resource_group.main.name
  location                      = data.azurerm_resource_group.main.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  shared_access_key_enabled     = true

  tags = var.tags
}

resource "azurerm_storage_container" "raw" {
  name                  = var.raw_container_name
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "processed" {
  name                  = var.processed_container_name
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# ── Cosmos DB ──────────────────────────────────────────────────────────────
resource "azurerm_cosmosdb_account" "main" {
  name                = var.cosmos_account_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = data.azurerm_resource_group.main.location
    failover_priority = 0
    zone_redundant    = false
  }

  tags = var.tags
}

resource "azurerm_cosmosdb_sql_database" "main" {
  name                = var.cosmos_database_name
  resource_group_name = data.azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
}

resource "azurerm_cosmosdb_sql_container" "parsed_documents" {
  name                = var.cosmos_container_name
  resource_group_name = data.azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  partition_key_paths = ["/employeeId"]

  indexing_policy {
    indexing_mode = "consistent"
  }
}

resource "azurerm_cosmosdb_sql_container" "incidents" {
  name                = "Incidents"
  resource_group_name = data.azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  partition_key_paths = ["/alertRule"]

  indexing_policy {
    indexing_mode = "consistent"
  }
}

# ── App Service Plan (reuse existing plan-taxforms in westus2) ──────────────
data "azurerm_service_plan" "main" {
  name                = "plan-taxforms"
  resource_group_name = data.azurerm_resource_group.main.name
}

# ── UI App Service ─────────────────────────────────────────────────────────
resource "azurerm_linux_web_app" "ui" {
  name                = var.ui_app_service_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_service_plan.main.location
  service_plan_id     = data.azurerm_service_plan.main.id

  site_config {
    always_on = false

    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"       = "1"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "false"
  }

  https_only = true

  tags = var.tags
}

# ── API App Service ────────────────────────────────────────────────────────
resource "azurerm_linux_web_app" "api" {
  name                = var.api_app_service_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_service_plan.main.location
  service_plan_id     = data.azurerm_service_plan.main.id

  site_config {
    always_on = false

    application_stack {
      python_version = "3.12"
    }
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"       = "1"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "false"
  }

  https_only = true

  tags = var.tags
}

# ── Microsoft Fabric Workspace ─────────────────────────────────────────────
# Fabric workspaces are managed via the Fabric REST API (not ARM). After
# terraform apply, create the workspace with:
#   az rest --method POST \
#     --url "https://api.fabric.microsoft.com/v1/workspaces" \
#     --body '{"displayName":"Fabric IQ – Employee Knowledge","capacityId":"<GUID>","description":"..."}'
# Then create OneLake lakehouse, semantic model, Power BI reports, and dashboards
# via the Fabric portal or REST API.
