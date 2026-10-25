output "vnet_id" {
  description = "Virtual network resource ID."
  value       = azurerm_virtual_network.this.id
}

output "private_dns_zone_link_ids" {
  description = "Private DNS VNet link IDs keyed by logical name."
  value       = { for name, link in azurerm_private_dns_zone_virtual_network_link.this : name => link.id }
}

output "subnet_ids" {
  description = "Subnet resource IDs keyed by name, after NSG/routing configuration."
  value       = { for name, subnet in azurerm_subnet.this : name => subnet.id }
  depends_on = [
    azurerm_network_security_rule.this,
    azurerm_subnet_network_security_group_association.this,
    azurerm_subnet_route_table_association.this,
    azurerm_route.this,
  ]
}

output "route_table_ids" {
  description = "Route table resource IDs keyed by logical name."
  value       = { for name, table in azurerm_route_table.this : name => table.id }
}

output "network_security_group_ids" {
  description = "NSG resource IDs keyed by subnet name."
  value       = { for name, nsg in azurerm_network_security_group.this : name => nsg.id }
}
