variable "resource_group_name" {
  type        = string
  description = "Existing resource group name (ai-myaacoub). All resources are deployed here."
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique storage account name."
}

variable "raw_container_name" {
  type        = string
  description = "Container for raw employee assets."
}

variable "processed_container_name" {
  type        = string
  description = "Container for processed employee assets."
}

variable "cosmos_account_name" {
  type        = string
  description = "Globally unique Cosmos DB account name."
}

variable "cosmos_database_name" {
  type        = string
  description = "Cosmos DB SQL database name."
}

variable "cosmos_container_name" {
  type        = string
  description = "Cosmos DB SQL container name."
}

variable "ui_app_service_name" {
  type        = string
  description = "Name of the UI App Service."
}

variable "api_app_service_name" {
  type        = string
  description = "Name of the API App Service."
}

variable "app_service_plan_name" {
  type        = string
  description = "Name of the dedicated App Service plan for Fabric IQ UI/API."
  default     = "plan-fabriciq-b3"
}

variable "app_service_plan_sku" {
  type        = string
  description = "SKU for the dedicated App Service plan for Fabric IQ UI/API."
  default     = "B3"
}

variable "app_service_plan_location" {
  type        = string
  description = "Location for the dedicated App Service plan. Must match the web apps' region."
  default     = "westus2"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
}

# ── Microsoft Fabric variables ────────────────────────────────────────────────

variable "fabric_capacity_id" {
  type        = string
  description = "Full resource ID of the Microsoft Fabric capacity to bind the workspace to."
}

variable "fabric_workspace_name" {
  type        = string
  description = "Internal name for the Fabric workspace resource."
  default     = "ws-fabriciq-emp-knowledge"
}

variable "fabric_workspace_display_name" {
  type        = string
  description = "Display name shown in the Fabric portal."
  default     = "Fabric IQ – Employee Knowledge"
}

# ── Azure Monitor variables ───────────────────────────────────────────────────

variable "existing_log_analytics_workspace_name" {
  type        = string
  description = "Name of an existing Log Analytics workspace in the resource group to reuse. Leave empty to create a new workspace."
  default     = ""
}

variable "sre_alert_email" {
  type        = string
  description = "Email address for the SRE action group alert notifications."
  default     = ""
}

variable "sre_webhook_url" {
  type        = string
  description = "Webhook URL for the SRE action group (e.g. Teams incoming webhook or existing SRE agent endpoint)."
  default     = ""
}
