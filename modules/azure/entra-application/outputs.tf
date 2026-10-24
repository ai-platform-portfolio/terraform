output "client_id" {
  description = "Application client ID for OIDC configuration."
  value       = azuread_application.this.client_id
}

output "object_id" {
  description = "Application object ID."
  value       = azuread_application.this.object_id
}

output "application_id" {
  description = "Provider resource ID for composing application-level resources, such as certificates."
  value       = azuread_application.this.id
}

output "principal_id" {
  description = "Service principal object ID for API consent and Azure RBAC."
  value       = azuread_service_principal.this.object_id
}

output "app_role_ids" {
  description = "Exposed app role IDs keyed by role value."
  value       = azuread_application.this.app_role_ids
}

output "oauth2_permission_scope_ids" {
  description = "Exposed delegated scope IDs keyed by scope value."
  value       = azuread_application.this.oauth2_permission_scope_ids
}
