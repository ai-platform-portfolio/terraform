output "id" {
  description = "Environment resource ID for Container Apps."
  value       = azurerm_container_app_environment.this.id
}

output "default_domain" {
  description = "Azure-generated environment domain."
  value       = azurerm_container_app_environment.this.default_domain
}
