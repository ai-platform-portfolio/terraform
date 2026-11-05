mock_provider "google" {}

variables {
  project_id   = "example-project"
  name         = "test-gateway"
  tenant_id    = "00000000-0000-0000-0000-000000000001"
  principal_id = "00000000-0000-0000-0000-000000000002"
  issuer       = "https://sts.windows.net/00000000-0000-0000-0000-000000000001/"
  audience     = "api://00000000-0000-0000-0000-000000000003"
}

run "restrict_runtime_identity" {
  command = plan
  assert {
    condition     = toset(google_iam_workload_identity_pool_provider.azure.oidc[0].allowed_audiences) == toset([var.audience]) && strcontains(google_iam_workload_identity_pool_provider.azure.attribute_condition, var.principal_id) && strcontains(google_iam_workload_identity_pool_provider.azure.attribute_condition, var.tenant_id) && strcontains(google_iam_workload_identity_pool_provider.azure.attribute_condition, "in assertion.roles")
    error_message = "Runtime trust must require dedicated audience, tenant, identity and app role."
  }
  assert {
    condition     = toset(google_project_iam_custom_role.inference.permissions) == toset(["aiplatform.endpoints.predict", "serviceusage.services.use"])
    error_message = "Runtime permissions must be limited to inference and API usage."
  }
}
