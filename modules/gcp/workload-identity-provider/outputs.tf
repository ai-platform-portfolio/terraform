output "provider" {
  description = "Created provider resource name for native external-account credentials."
  value       = google_iam_workload_identity_pool_provider.this.name
  sensitive   = true
}
