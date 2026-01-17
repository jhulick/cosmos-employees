output "cosmos_endpoint" {
  value       = azurerm_cosmosdb_account.cosmos.endpoint
  description = "Cosmos DB endpoint URL"
}

output "cosmos_primary_key" {
  value       = azurerm_cosmosdb_account.cosmos.primary_key
  sensitive   = true
  description = "Primary key (use only for debugging; prefer Managed Identity)"
}

output "database_name" {
  value = azurerm_cosmosdb_sql_database.db.name
}

output "container_name" {
  value = azurerm_cosmosdb_sql_container.employees.name
}
