output "id" {
  description = "Parent resource ID."
  value       = azurerm_managed_redis.this.id
}

output "name" {
  description = "Parent resource name."
  value       = azurerm_managed_redis.this.name
}

output "principal_id" {
  description = "System-assigned identity principal ID, when enabled."
  value       = try(azurerm_managed_redis.this.identity[0].principal_id, null)
}

output "private_endpoint_ids" {
  description = "Private endpoint IDs keyed by purpose."
  value       = { for key, endpoint in azurerm_private_endpoint.this : key => endpoint.id }
}

output "hostname" {
  description = "Redis service hostname."
  value       = azurerm_managed_redis.this.hostname
}

output "database_id" {
  description = "Default database ID."
  value       = azurerm_managed_redis.this.default_database[0].id
}

output "port" {
  description = "Redis database port."
  value       = azurerm_managed_redis.this.default_database[0].port
}

output "access_policy_assignment_ids" {
  description = "Data access assignment IDs keyed by purpose."
  value       = { for key, assignment in azurerm_managed_redis_access_policy_assignment.this : key => assignment.id }
}
