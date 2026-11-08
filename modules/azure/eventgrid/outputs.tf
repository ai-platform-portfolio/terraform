output "id" {
  description = "Parent resource ID."
  value       = azurerm_eventgrid_domain.this.id
}

output "name" {
  description = "Parent resource name."
  value       = azurerm_eventgrid_domain.this.name
}

output "principal_id" {
  description = "System-assigned identity principal ID, when enabled."
  value       = try(azurerm_eventgrid_domain.this.identity[0].principal_id, null)
}

output "private_endpoint_ids" {
  description = "Private endpoint IDs keyed by purpose."
  value       = { for key, endpoint in azurerm_private_endpoint.this : key => endpoint.id }
}

output "role_assignment_ids" {
  description = "Parent-scoped role assignment IDs."
  value       = { for key, assignment in azurerm_role_assignment.this : key => assignment.id }
}

output "topic_ids" {
  description = "Topic IDs keyed by caller map keys."
  value       = { for key, resource in azurerm_eventgrid_domain_topic.this : key => resource.id }
}

output "event_subscription_ids" {
  description = "Event subscription IDs keyed by caller map keys."
  value       = { for key, resource in azurerm_eventgrid_event_subscription.this : key => resource.id }
}

output "endpoint" {
  description = "Domain publishing endpoint."
  value       = azurerm_eventgrid_domain.this.endpoint
}
