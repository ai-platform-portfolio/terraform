output "id" {
  description = "Flexible Server resource ID."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "name" {
  description = "Flexible Server name."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "fqdn" {
  description = "Flexible Server hostname for verified TLS connections."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "private_endpoint_id" {
  description = "Private endpoint resource ID."
  value       = azurerm_private_endpoint.this.id
}
