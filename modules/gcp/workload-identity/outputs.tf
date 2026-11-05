output "provider" {
  description = "Google workload identity provider resource name."
  value       = google_iam_workload_identity_pool_provider.azure.name
  sensitive   = true
}

output "service_account" {
  description = "Federated service account email."
  value       = google_service_account.runtime.email
  sensitive   = true
}

output "token_exchange" {
  description = "Endpoints and audiences for the caller to obtain short-lived Google credentials."
  value = {
    audience                  = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.azure.name}"
    entra_audience            = var.audience
    sts_url                   = "https://sts.googleapis.com/v1/token"
    service_account_token_url = "https://iamcredentials.googleapis.com/v1/${google_service_account.runtime.name}:generateAccessToken"
  }
  sensitive = true
}
