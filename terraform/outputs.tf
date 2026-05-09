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

output "api_app_service_url" {
  value       = "https://${azurerm_linux_web_app.api.default_hostname}"
  description = "Public URL of the newly provisioned dedicated API App Service."
}
