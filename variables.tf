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

variable "tenant_id" {
  description = "Tenant ID"
  type        = string
  default     = "e66ee3e4-9119-4d4d-a6bd-4b1e6aa180c5"
}

variable "client_id" {
  description = "Tenant ID"
  type        = string
  default     = ""
}

variable "client_secret" {
  description = "Tenant ID"
  type        = string
  default     = ""
}

#variable "app_service_principal_id" {
#  description = "Principal ID of the App Service / Function Managed Identity"
#  type        = string
#}

variable "app_service_plan_name" {
  type        = string
  description = "The app service plan name."
  default     = "employee-app-plan"
}

variable "app_service_name" {
  type        = string
  description = "The app service name."
  default     = "employee-app-svc"
}

variable "api_source_path" {
  type        = string
  description = "The path to the react app source."
  default     = "./employee-api"
}
