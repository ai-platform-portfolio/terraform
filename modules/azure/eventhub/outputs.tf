output "id" {
  description = "Parent resource ID."
  value       = azurerm_eventhub_namespace.this.id
}

output "name" {
  description = "Parent resource name."
  value       = azurerm_eventhub_namespace.this.name
}

output "principal_id" {
  description = "System-assigned identity principal ID, when enabled."
  value       = try(azurerm_eventhub_namespace.this.identity[0].principal_id, null)
}

output "private_endpoint_ids" {
  description = "Private endpoint IDs keyed by purpose."
  value       = { for key, endpoint in azurerm_private_endpoint.this : key => endpoint.id }
}

output "role_assignment_ids" {
  description = "Parent-scoped role assignment IDs."
  value       = { for key, assignment in azurerm_role_assignment.this : key => assignment.id }
}

output "eventhub_ids" {
  description = "Eventhub IDs keyed by caller map keys."
  value       = { for key, resource in azurerm_eventhub.this : key => resource.id }
}

output "consumer_group_ids" {
  description = "Consumer group IDs keyed by caller map keys."
  value       = { for key, resource in azurerm_eventhub_consumer_group.this : key => resource.id }
}
