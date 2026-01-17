variable "location" {
  description = "Azure region"
  type        = string
  default     = "westus2"
}

variable "cosmos_account_name_prefix" {
  description = "Prefix for Cosmos DB account name (will be made unique)"
  type        = string
  default     = "cosmos-employees-"
}

#variable "app_service_principal_id" {
#  description = "Principal ID of the App Service / Function Managed Identity"
#  type        = string
#}
