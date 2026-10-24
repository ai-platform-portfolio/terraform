output "client_id" {
  description = "Application client ID for OIDC configuration."
  value       = azuread_application.this.client_id
}

output "object_id" {
  description = "Application object ID."
  value       = azuread_application.this.object_id
}

output "principal_id" {
  description = "Service principal object ID."
  value       = azuread_service_principal.this.object_id
}
