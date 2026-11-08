output "id" {
  description = "Parent resource ID."
  value       = azurerm_servicebus_namespace.this.id
}

output "name" {
  description = "Parent resource name."
  value       = azurerm_servicebus_namespace.this.name
}

output "principal_id" {
  description = "System-assigned identity principal ID, when enabled."
  value       = try(azurerm_servicebus_namespace.this.identity[0].principal_id, null)
}

output "private_endpoint_ids" {
  description = "Private endpoint IDs keyed by purpose."
  value       = { for key, endpoint in azurerm_private_endpoint.this : key => endpoint.id }
}

output "role_assignment_ids" {
  description = "Parent-scoped role assignment IDs."
  value       = { for key, assignment in azurerm_role_assignment.this : key => assignment.id }
}

output "queue_ids" {
  description = "Queue IDs keyed by caller map keys."
  value       = { for key, resource in azurerm_servicebus_queue.this : key => resource.id }
}

output "topic_ids" {
  description = "Topic IDs keyed by caller map keys."
  value       = { for key, resource in azurerm_servicebus_topic.this : key => resource.id }
}

output "subscription_ids" {
  description = "Subscription IDs keyed by caller map keys."
  value       = { for key, resource in azurerm_servicebus_subscription.this : key => resource.id }
}

output "subscription_rule_ids" {
  description = "Subscription rule IDs keyed by caller map keys."
  value       = { for key, resource in azurerm_servicebus_subscription_rule.this : key => resource.id }
}

output "endpoint" {
  description = "Namespace endpoint."
  value       = azurerm_servicebus_namespace.this.endpoint
}
