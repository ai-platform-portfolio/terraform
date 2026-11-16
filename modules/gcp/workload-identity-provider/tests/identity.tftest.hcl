mock_provider "google" {}

override_resource {
  target = google_iam_workload_identity_pool_provider.this
  values = {
    name = "projects/123456789/locations/global/workloadIdentityPools/existing/providers/example-aks"
  }
}

variables {
  project_id            = "example-project"
  pool_id               = "existing"
  provider_id           = "example-aks"
  service_account_email = "gateway@example-project.iam.gserviceaccount.com"
  trust = {
    issuer   = "https://issuer.example.test/"
    audience = "api://example-google"
    subject  = "system:serviceaccount:gateway:proxy"
  }
}

run "restrict_existing_account_access" {
  command = apply

  assert {
    condition     = google_iam_workload_identity_pool_provider.this.oidc[0].issuer_uri == var.trust.issuer && google_iam_workload_identity_pool_provider.this.oidc[0].allowed_audiences == tolist([var.trust.audience]) && google_iam_workload_identity_pool_provider.this.attribute_mapping == tomap({ "google.subject" = "assertion.sub" }) && google_iam_workload_identity_pool_provider.this.attribute_condition == "assertion.sub == \"system:serviceaccount:gateway:proxy\""
    error_message = "Only the exact issuer, audience and ServiceAccount subject may exchange a token."
  }

  assert {
    condition     = google_service_account_iam_member.this.member == "principal://iam.googleapis.com/projects/123456789/locations/global/workloadIdentityPools/existing/subject/system:serviceaccount:gateway:proxy" && google_service_account_iam_member.this.role == "roles/iam.workloadIdentityUser" && google_service_account_iam_member.this.service_account_id == "projects/example-project/serviceAccounts/gateway@example-project.iam.gserviceaccount.com"
    error_message = "Grant only this subject impersonation on the supplied existing account."
  }
}

run "reject_non_kubernetes_subject" {
  command = plan
  variables {
    trust = { issuer = "https://issuer.example.test/", audience = "api://example", subject = "*" }
  }
  expect_failures = [var.trust]
}
