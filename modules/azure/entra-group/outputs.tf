output "object_id" {
  description = "Entra group object ID, for example for AKS admin_group_object_ids."
  value       = azuread_group.this.object_id
}
