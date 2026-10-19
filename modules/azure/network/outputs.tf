output "vnet_id" {
  description = "Virtual network resource ID."
  value       = azurerm_virtual_network.this.id
}
output "subnet_ids" {
  description = "Subnet resource IDs keyed by name, after NSG association."
  value       = { for name, subnet in azurerm_subnet.this : name => subnet.id }
  depends_on  = [azurerm_subnet_network_security_group_association.this]
}
