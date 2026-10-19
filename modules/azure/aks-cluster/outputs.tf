output "cluster_id" {
  description = "AKS resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}
output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}
output "oidc_issuer_url" {
  description = "Issuer for workload federation."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}
output "kubelet_identity" {
  description = "AKS kubelet identity."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity
}
