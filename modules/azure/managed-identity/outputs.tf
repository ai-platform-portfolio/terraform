output "identity_id" {
  description = "Identity resource ID."
  value       = azurerm_user_assigned_identity.this.id
}

output "client_id" {
  description = "Client ID for workload identity annotations."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "principal_id" {
  description = "Principal ID for scoped RBAC assignments."
  value       = azurerm_user_assigned_identity.this.principal_id
}
