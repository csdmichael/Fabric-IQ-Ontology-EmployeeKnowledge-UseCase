variable "location" {
  type        = string
  description = "Azure region for all resources."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name."
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
  description = "Name of the new UI App Service in the ai-myaacoub resource group."
}

variable "ui_resource_group_name" {
  type        = string
  description = "Resource group that contains the existing App Service Plan for the UI."
}

variable "ui_app_service_plan_name" {
  type        = string
  description = "Name of the existing App Service Plan to reuse for the UI app."
}

variable "api_app_service_name" {
  type        = string
  description = "Name of the new dedicated API App Service (does not overwrite any existing app)."
}

variable "api_resource_group_name" {
  type        = string
  description = "Resource group that contains the existing App Service Plan for the API."
}

variable "api_app_service_plan_name" {
  type        = string
  description = "Name of the existing App Service Plan to reuse for the API app."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
}
