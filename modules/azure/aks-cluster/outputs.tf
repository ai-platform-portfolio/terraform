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

output "host" {
  description = "Kubernetes API endpoint, available after all node pools are provisioned."
  value       = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive   = true
  depends_on  = [azurerm_kubernetes_cluster_node_pool.this]
}

output "cluster_ca_certificate" {
  description = "Decoded Kubernetes cluster CA certificate, available after all node pools are provisioned."
  value       = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
  sensitive   = true
  depends_on  = [azurerm_kubernetes_cluster_node_pool.this]
}
