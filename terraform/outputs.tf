output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "cosmos_account_name" {
  value = azurerm_cosmosdb_account.main.name
}

output "ui_app_service_url" {
  value       = "https://${azurerm_linux_web_app.ui.default_hostname}"
  description = "Public URL of the newly provisioned UI App Service."
}

output "monitor_action_group_id" {
  value       = azurerm_monitor_action_group.sre.id
  description = "Resource ID of the SRE action group used by all Azure Monitor alerts."
}

output "incident_response_logic_app_trigger_url" {
  value       = azurerm_logic_app_trigger_http_request.alert_receiver.callback_url
  description = "HTTP trigger URL for the incident response Logic App. Add this as the webhook URL in the SRE action group and in sre_webhook_url tfvar."
  sensitive   = true
}

output "log_analytics_workspace_id" {
  value       = local.log_analytics_workspace_id
  description = "Log Analytics workspace used for all diagnostic settings and scheduled query alerts."
}
