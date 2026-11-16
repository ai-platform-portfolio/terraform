terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.6, < 9.0"
    }
  }
}

# The caller's existing pool/account retain their original owner and lifecycle.
resource "google_iam_workload_identity_pool_provider" "this" {
  project                            = var.project_id
  workload_identity_pool_id          = var.pool_id
  workload_identity_pool_provider_id = var.provider_id
  attribute_mapping                  = { "google.subject" = "assertion.sub" }
  attribute_condition                = "assertion.sub == ${jsonencode(var.trust.subject)}"

  oidc {
    issuer_uri        = var.trust.issuer
    allowed_audiences = [var.trust.audience]
  }
}

resource "google_service_account_iam_member" "this" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${trimsuffix(google_iam_workload_identity_pool_provider.this.name, "/providers/${var.provider_id}")}/subject/${var.trust.subject}"
}
