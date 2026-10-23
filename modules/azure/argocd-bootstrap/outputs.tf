output "release_name" {
  description = "ArgoCD Helm release name."
  value       = helm_release.this.name
}

output "namespace" {
  description = "ArgoCD namespace."
  value       = helm_release.this.namespace
}
