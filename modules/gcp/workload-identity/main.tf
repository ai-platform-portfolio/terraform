terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.6, < 9.0"
    }
  }
}

resource "google_iam_workload_identity_pool" "runtime" {
  project                   = var.project_id
  workload_identity_pool_id = "${var.name}-runtime"
  display_name              = "${var.name} Azure runtime"
}

resource "google_iam_workload_identity_pool_provider" "azure" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.runtime.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  attribute_mapping = {
    "google.subject" = "assertion.oid"
  }
  attribute_condition = "assertion.tid == '${var.tenant_id}' && assertion.oid == '${var.principal_id}' && '${var.role_value}' in assertion.roles"
  oidc {
    issuer_uri        = var.issuer
    allowed_audiences = [var.audience]
  }
}

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = var.name
  display_name = "${var.name} federated workload"
}

resource "google_service_account_iam_member" "azure" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.runtime.name}/subject/${var.principal_id}"
  depends_on         = [google_iam_workload_identity_pool_provider.azure]
}

resource "google_project_iam_custom_role" "access" {
  project     = var.project_id
  role_id     = var.role.id
  title       = var.role.title
  description = var.role.description
  permissions = var.role.permissions
}

resource "google_project_iam_member" "access" {
  project = var.project_id
  role    = google_project_iam_custom_role.access.name
  member  = "serviceAccount:${google_service_account.runtime.email}"
}
