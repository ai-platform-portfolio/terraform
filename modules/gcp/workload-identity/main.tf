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
  display_name              = "${var.name} federated runtime"
}

resource "google_iam_workload_identity_pool_provider" "azure" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.runtime.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  attribute_mapping = {
    "google.subject" = var.subject == null ? "assertion.oid" : "assertion.sub"
  }
  attribute_condition = var.subject != null ? "assertion.sub == '${var.subject}'" : "assertion.tid == '${coalesce(var.tenant_id, "unset")}' && assertion.oid == '${coalesce(var.principal_id, "unset")}' && '${coalesce(var.role_value, "unset")}' in assertion.roles"
  oidc {
    issuer_uri        = var.issuer
    allowed_audiences = [var.audience]
  }

  lifecycle {
    precondition {
      condition     = var.subject != null || alltrue([var.tenant_id != null, var.principal_id != null, var.role_value != null])
      error_message = "Declare either an exact native OIDC subject or the complete existing Entra claim contract."
    }
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
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.runtime.name}/subject/${var.subject != null ? var.subject : var.principal_id}"
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
