output "id" {
  description = "Container App resource ID."
  value       = azurerm_container_app.this.id
}

output "fqdn" {
  description = "Azure-generated ingress hostname."
  value       = azurerm_container_app.this.ingress[0].fqdn
}

output "url" {
  description = "HTTPS URL, using the custom hostname when configured; reachability follows ingress settings."
  value       = "https://${var.custom_domain == null ? azurerm_container_app.this.ingress[0].fqdn : var.custom_domain.hostname}"
}
