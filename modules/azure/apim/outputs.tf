output "id" {
  description = "API Management resource ID, ready for private gateway use."
  value       = azurerm_api_management.this.id
  depends_on  = [azapi_update_resource.private_access]
}

output "gateway_url" {
  description = "Gateway URL; clients must resolve its private endpoint through DNS."
  value       = azurerm_api_management.this.gateway_url
  depends_on  = [azapi_update_resource.private_access]
}

output "private_endpoint_id" {
  description = "Inbound gateway private endpoint resource ID."
  value       = azurerm_private_endpoint.this.id
}
