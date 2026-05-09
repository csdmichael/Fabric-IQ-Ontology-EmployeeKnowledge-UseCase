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

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
}
