resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

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

resource "azurerm_cosmosdb_account" "main" {
  name                = var.cosmos_account_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  tags = var.tags
}

resource "azurerm_cosmosdb_sql_database" "main" {
  name                = var.cosmos_database_name
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
}

resource "azurerm_cosmosdb_sql_container" "parsed_documents" {
  name                = var.cosmos_container_name
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  partition_key_paths = ["/employeeId"]

  indexing_policy {
    indexing_mode = "consistent"
  }
}

# ── UI App Service (new, dedicated) ────────────────────────────────────────
# Looks up the existing App Service Plan in ai-myaacoub (not managed by this
# Terraform workspace) and creates a new web app that shares it.
data "azurerm_resource_group" "ui" {
  name = var.ui_resource_group_name
}

data "azurerm_service_plan" "ui" {
  name                = var.ui_app_service_plan_name
  resource_group_name = data.azurerm_resource_group.ui.name
}

resource "azurerm_linux_web_app" "ui" {
  name                = var.ui_app_service_name
  resource_group_name = data.azurerm_resource_group.ui.name
  location            = data.azurerm_resource_group.ui.location
  service_plan_id     = data.azurerm_service_plan.ui.id

  site_config {
    # always_on = false is appropriate for this demo environment to stay within
    # the B1 SKU free quota. Set to true for production workloads to eliminate cold starts.
    always_on = false

    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "false"
  }

  https_only = true

  tags = var.tags
}

# ── API App Service (new, dedicated) ───────────────────────────────────────
# Looks up the existing App Service Plan (not managed by this Terraform
# workspace) and creates a new web app for the Fabric IQ API. This does NOT
# touch the pre-existing foundry-privatevnet-api app that hosts other workloads.
data "azurerm_resource_group" "api" {
  name = var.api_resource_group_name
}

data "azurerm_service_plan" "api" {
  name                = var.api_app_service_plan_name
  resource_group_name = data.azurerm_resource_group.api.name
}

resource "azurerm_linux_web_app" "api" {
  name                = var.api_app_service_name
  resource_group_name = data.azurerm_resource_group.api.name
  location            = data.azurerm_resource_group.api.location
  service_plan_id     = data.azurerm_service_plan.api.id

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
