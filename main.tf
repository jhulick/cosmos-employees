terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

# ──────────────────────────────────────────────────────────────────────────────
# Resource Group
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "rg" {
  name     = "cosmos-employees-rg"
  location = var.location
}

# ──────────────────────────────────────────────────────────────────────────────
# Cosmos DB Account (SQL API) - Private by default
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_cosmosdb_account" "cosmos" {
  name                              = "${var.cosmos_account_name_prefix}${random_string.unique.result}"
  location                          = azurerm_resource_group.rg.location
  resource_group_name               = azurerm_resource_group.rg.name
  offer_type                        = "Standard"
  kind                              = "GlobalDocumentDB"
  enable_automatic_failover         = false
  enable_multiple_write_locations   = false
  public_network_access_enabled     = false   # Enforce private endpoint only
  ip_range_filter                   = null

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }

  backup {
    type                = "Periodic"
    interval_in_minutes = 1440
    retention_in_hours  = 720
    storage_redundancy  = "Geo"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Cosmos DB SQL Database & Container
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_cosmosdb_sql_database" "db" {
  name                = "employeesdb"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "employees" {
  name                  = "employees"
  resource_group_name   = azurerm_resource_group.rg.name
  account_name          = azurerm_cosmosdb_account.cosmos.name
  database_name         = azurerm_cosmosdb_sql_database.db.name
  partition_key_path    = "/id"
  throughput            = 400

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/\"_etag\"/?"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# System-Assigned Managed Identity for App Service / Function
# ──────────────────────────────────────────────────────────────────────────────
#resource "azurerm_role_assignment" "cosmos_data_contributor" {
#  scope                = azurerm_cosmosdb_account.cosmos.id
#  role_definition_name = "Cosmos DB Built-in Data Contributor"
#  principal_id         = var.app_service_principal_id  # Pass from your App Service module
#}

# ──────────────────────────────────────────────────────────────────────────────
# User-Assigned Managed Identity (shared for Function App + App Service)
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_user_assigned_identity" "app_identity" {
  name                = "employee-app-identity"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}

# Grant Cosmos DB data access to the user-assigned identity
resource "azurerm_role_assignment" "cosmos_data_contributor" {
  scope                = azurerm_cosmosdb_account.cosmos.id
  role_definition_name = "Cosmos DB Built-in Data Contributor"
  principal_id         = azurerm_user_assigned_identity.app_identity.principal_id
}

# Random suffix for unique Cosmos account name
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}
