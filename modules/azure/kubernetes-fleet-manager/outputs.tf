output "id" {
  description = "Fleet ARM resource ID for membership in cluster deployment roots."
  value       = azurerm_kubernetes_fleet_manager.this.id
}

output "name" {
  description = "Fleet Manager name."
  value       = azurerm_kubernetes_fleet_manager.this.name
}
