# ── Azure Monitor – Log Analytics Workspace ──────────────────────────────────

data "azurerm_log_analytics_workspace" "sre" {
  count               = var.existing_log_analytics_workspace_name != "" ? 1 : 0
  name                = var.existing_log_analytics_workspace_name
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_log_analytics_workspace" "main" {
  count               = var.existing_log_analytics_workspace_name != "" ? 0 : 1
  name                = "law-fabriciq-emp-knowledge"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

locals {
  log_analytics_workspace_id = (
    var.existing_log_analytics_workspace_name != ""
    ? data.azurerm_log_analytics_workspace.sre[0].id
    : azurerm_log_analytics_workspace.main[0].id
  )
}

# ── Action Group ──────────────────────────────────────────────────────────────

resource "azurerm_monitor_action_group" "sre" {
  name                = "ag-fabriciq-sre"
  resource_group_name = data.azurerm_resource_group.main.name
  short_name          = "fab-iq-sre"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.sre_alert_email != "" ? [1] : []
    content {
      name                    = "SRE Email"
      email_address           = var.sre_alert_email
      use_common_alert_schema = true
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.sre_webhook_url != "" ? [1] : []
    content {
      name                    = "SRE Webhook"
      service_uri             = var.sre_webhook_url
      use_common_alert_schema = true
    }
  }
}

# ── Diagnostic Settings – Storage Account ────────────────────────────────────

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "diag-storage-fabriciq"
  target_resource_id         = "${azurerm_storage_account.main.id}/blobServices/default"
  log_analytics_workspace_id = local.log_analytics_workspace_id

  enabled_log { category = "StorageRead" }
  enabled_log { category = "StorageWrite" }
  enabled_log { category = "StorageDelete" }

  metric {
    category = "Transaction"
    enabled  = true
  }
}

# ── Diagnostic Settings – Cosmos DB ──────────────────────────────────────────

resource "azurerm_monitor_diagnostic_setting" "cosmos" {
  name                       = "diag-cosmos-fabriciq"
  target_resource_id         = azurerm_cosmosdb_account.main.id
  log_analytics_workspace_id = local.log_analytics_workspace_id

  enabled_log { category = "DataPlaneRequests" }
  enabled_log { category = "QueryRuntimeStatistics" }
  enabled_log { category = "PartitionKeyStatistics" }
  enabled_log { category = "ControlPlaneRequests" }

  metric {
    category = "Requests"
    enabled  = true
  }
}

# ── Diagnostic Settings – UI App Service ─────────────────────────────────────

resource "azurerm_monitor_diagnostic_setting" "ui_app" {
  name                       = "diag-ui-fabriciq"
  target_resource_id         = azurerm_linux_web_app.ui.id
  log_analytics_workspace_id = local.log_analytics_workspace_id

  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_log { category = "AppServiceConsoleLogs" }
  enabled_log { category = "AppServiceAppLogs" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ── Metric Alerts ─────────────────────────────────────────────────────────────

resource "azurerm_monitor_metric_alert" "storage_availability" {
  name                = "alert-storage-availability-fabriciq"
  resource_group_name = data.azurerm_resource_group.main.name
  scopes              = [azurerm_storage_account.main.id]
  description         = "Fires when blob storage availability drops below 99%."
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Availability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99
  }

  action { action_group_id = azurerm_monitor_action_group.sre.id }
}

resource "azurerm_monitor_metric_alert" "cosmos_server_errors" {
  name                = "alert-cosmos-server-errors-fabriciq"
  resource_group_name = data.azurerm_resource_group.main.name
  scopes              = [azurerm_cosmosdb_account.main.id]
  description         = "Fires when Cosmos DB returns more than 5 server-side (5xx) errors in 5 minutes."
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.DocumentDB/databaseAccounts"
    metric_name      = "TotalRequests"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5

    dimension {
      name     = "StatusCode"
      operator = "Include"
      values   = ["500", "503"]
    }
  }

  action { action_group_id = azurerm_monitor_action_group.sre.id }
}

resource "azurerm_monitor_metric_alert" "cosmos_ru_throttle" {
  name                = "alert-cosmos-ru-throttle-fabriciq"
  resource_group_name = data.azurerm_resource_group.main.name
  scopes              = [azurerm_cosmosdb_account.main.id]
  description         = "Fires when Cosmos DB returns 429 (Too Many Requests) throttling responses."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.DocumentDB/databaseAccounts"
    metric_name      = "TotalRequests"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10

    dimension {
      name     = "StatusCode"
      operator = "Include"
      values   = ["429"]
    }
  }

  action { action_group_id = azurerm_monitor_action_group.sre.id }
}

resource "azurerm_monitor_metric_alert" "ui_http5xx" {
  name                = "alert-ui-http5xx-fabriciq"
  resource_group_name = data.azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.ui.id]
  description         = "Fires when UI app returns more than 5 HTTP 5xx errors in 5 minutes."
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action { action_group_id = azurerm_monitor_action_group.sre.id }
}

resource "azurerm_monitor_metric_alert" "ui_response_time" {
  name                = "alert-ui-response-time-fabriciq"
  resource_group_name = data.azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.ui.id]
  description         = "Fires when average response time exceeds 5 seconds over a 15-minute window."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "AverageResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action { action_group_id = azurerm_monitor_action_group.sre.id }
}

# ── Scheduled Query Alert – Low Confidence Docs ──────────────────────────────

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "low_confidence_docs" {
  name                = "sqr-low-confidence-docs-fabriciq"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  description         = "Fires when more than 10 parsed documents have confidence below 0.5 in the last hour."
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                  = [local.log_analytics_workspace_id]
  evaluation_frequency    = "PT15M"
  window_duration         = "PT1H"
  auto_mitigation_enabled = true
  skip_query_validation   = true

  criteria {
    query = <<-KQL
      AzureDiagnostics
      | where ResourceProvider == "MICROSOFT.DOCUMENTDB"
      | where Category == "DataPlaneRequests"
      | where requestResourceId_s contains "EmployeeDocumentParsing"
      | where todouble(parse_json(properties_s).documentConfidence) < 0.5
      | summarize LowConfidenceCount = count()
      | where LowConfidenceCount > 10
    KQL

    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.sre.id]
  }
}

# ── Incident Response Logic App ───────────────────────────────────────────────

resource "azurerm_logic_app_workflow" "incident_response" {
  name                = "logic-fabriciq-incident-response"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = var.tags

  parameters = {
    "$connections"    = jsonencode({})
    "cosmosEndpoint"  = azurerm_cosmosdb_account.main.endpoint
    "teamsWebhookUrl" = var.sre_webhook_url
  }

  workflow_parameters = {
    "$connections" = jsonencode({
      defaultValue = {}
      type         = "Object"
    })
    "cosmosEndpoint" = jsonencode({
      defaultValue = ""
      type         = "String"
    })
    "teamsWebhookUrl" = jsonencode({
      defaultValue = ""
      type         = "String"
    })
  }
}

resource "azurerm_logic_app_trigger_http_request" "alert_receiver" {
  name         = "When_an_Azure_Monitor_alert_fires"
  logic_app_id = azurerm_logic_app_workflow.incident_response.id

  schema = jsonencode({
    type = "object"
    properties = {
      schemaId = { type = "string" }
      data = {
        type = "object"
        properties = {
          essentials = {
            type = "object"
            properties = {
              alertId             = { type = "string" }
              alertRule           = { type = "string" }
              severity            = { type = "string" }
              signalType          = { type = "string" }
              monitorCondition    = { type = "string" }
              monitoringService   = { type = "string" }
              alertTargetIDs      = { type = "array", items = { type = "string" } }
              configurationItems  = { type = "array", items = { type = "string" } }
              originAlertId       = { type = "string" }
              firedDateTime       = { type = "string" }
              description         = { type = "string" }
              essentialsVersion   = { type = "string" }
              alertContextVersion = { type = "string" }
            }
          }
          alertContext = {
            type = "object"
            properties = {
              properties    = { type = "object" }
              conditionType = { type = "string" }
              condition     = { type = "object" }
            }
          }
        }
      }
    }
  })
}

resource "azurerm_logic_app_action_custom" "log_incident" {
  name         = "Log_Incident_to_Cosmos"
  logic_app_id = azurerm_logic_app_workflow.incident_response.id

  body = jsonencode({
    type = "Http"
    inputs = {
      method = "POST"
      uri    = "@{parameters('cosmosEndpoint')}/dbs/EmployeeKnowledgeGraph/colls/Incidents/docs"
      headers = {
        "x-ms-documentdb-partitionkey" = "[\"@{triggerBody()?['data']?['essentials']?['alertRule']}\"]"
        "Content-Type"                 = "application/json"
      }
      body = {
        id           = "@{guid()}"
        alertRule    = "@{triggerBody()?['data']?['essentials']?['alertRule']}"
        severity     = "@{triggerBody()?['data']?['essentials']?['severity']}"
        firedAt      = "@{triggerBody()?['data']?['essentials']?['firedDateTime']}"
        description  = "@{triggerBody()?['data']?['essentials']?['description']}"
        status       = "Open"
        incidentType = "AzureMonitorAlert"
      }
    }
    runAfter = {}
  })
}

resource "azurerm_logic_app_action_custom" "notify_teams" {
  name         = "Notify_SRE_Teams_Channel"
  logic_app_id = azurerm_logic_app_workflow.incident_response.id

  body = jsonencode({
    type = "Http"
    inputs = {
      method  = "POST"
      uri     = "@{parameters('teamsWebhookUrl')}"
      headers = { "Content-Type" = "application/json" }
      body = {
        "@@type"    = "MessageCard"
        "@@context" = "http://schema.org/extensions"
        themeColor = "FF0000"
        summary    = "Fabric IQ Monitor Alert Fired"
        sections = [
          {
            activityTitle    = "Fabric IQ Monitor Alert"
            activitySubtitle = "@{triggerBody()?['data']?['essentials']?['alertRule']}"
            facts = [
              { name = "Severity", value = "@{triggerBody()?['data']?['essentials']?['severity']}" },
              { name = "Fired At", value = "@{triggerBody()?['data']?['essentials']?['firedDateTime']}" },
              { name = "Description", value = "@{triggerBody()?['data']?['essentials']?['description']}" }
            ]
          }
        ]
      }
    }
    runAfter = { "Log_Incident_to_Cosmos" = ["Succeeded"] }
  })
}
