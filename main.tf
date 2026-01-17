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

# ──────────────────────────────────────────────────────────────────────────────
# Seed initial data using local-exec (Python script)
# ──────────────────────────────────────────────────────────────────────────────
resource "null_resource" "seed_employees" {
  depends_on = [
    azurerm_cosmosdb_sql_container.employees
  ]

  provisioner "local-exec" {
    command = "python3 ${path.module}/seed_employees.py"
    environment = {
      COSMOS_ENDPOINT   = azurerm_cosmosdb_account.cosmos.endpoint
      COSMOS_KEY        = azurerm_cosmosdb_account.cosmos.primary_key
      DATABASE_NAME     = azurerm_cosmosdb_sql_database.db.name
      CONTAINER_NAME    = azurerm_cosmosdb_sql_container.employees.name
    }
  }

  # Optional: Trigger re-seed on container change
  triggers = {
    container_id = azurerm_cosmosdb_sql_container.employees.id
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Temporary Storage Account + Container for seeding file
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_storage_account" "seed_storage" {
  name                     = "seed${random_string.unique.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "seed_container" {
  name                  = "seed-data"
  storage_account_name  = azurerm_storage_account.seed_storage.name
  container_access_type = "private"
}

# Upload seed JSON file
resource "azurerm_storage_blob" "seed_json" {
  name                   = "employees_seed.json"
  storage_account_name   = azurerm_storage_account.seed_storage.name
  storage_container_name = azurerm_storage_container.seed_container.name
  type                   = "Block"
  source                 = "${path.module}/../../employees_seed.json"  # Path relative to root
  content_type           = "application/json"
}

# Generate SAS token (read-only, 1-hour expiry)
data "azurerm_storage_account_blob_container_sas" "seed_sas" {
  connection_string = azurerm_storage_account.seed_storage.primary_connection_string
  container_name    = azurerm_storage_container.seed_container.name
  https_only        = true

  start  = timeadd(timestamp(), "-5m")
  expiry = timeadd(timestamp(), "1h")

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Create Stored Procedure
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_cosmosdb_sql_stored_procedure" "bulk_insert" {
  name                = "bulkInsertEmployees"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.db.name
  container_name        = azurerm_cosmosdb_sql_container.employees.name
  body                = file("${path.module}/seed_procedure.js")
}

# ──────────────────────────────────────────────────────────────────────────────
# Execute seeding via AzCopy + Stored Procedure (local-exec)
# ──────────────────────────────────────────────────────────────────────────────
resource "null_resource" "seed_cosmos" {
  depends_on = [
    azurerm_cosmosdb_sql_stored_procedure.bulk_insert,
    azurerm_storage_blob.seed_json
  ]

  provisioner "local-exec" {
    command = <<EOT
      azcopy copy "${azurerm_storage_blob.seed_json.url}${data.azurerm_storage_account_blob_container_sas.seed_sas.sas}" \
        "https://${azurerm_cosmosdb_account.cosmos.name}.documents.azure.com:443/dbs/${azurerm_cosmosdb_sql_database.db.name}/colls/${azurerm_cosmosdb_sql_container.employees.name}/sprocs/bulkInsertEmployees" \
        --service-principal \
        --tenant-id ${var.tenant_id} \
        --client-id ${var.client_id} \
        --client-secret ${var.client_secret} \
        --method POST
    EOT
  }

  # Optional: Trigger re-seed if container or data changes
  triggers = {
    container_id = azurerm_cosmosdb_sql_container.employees.id
    seed_file    = filemd5("${path.module}/employees_seed.json")
  }
}

# Random suffix for unique Cosmos account name
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}
