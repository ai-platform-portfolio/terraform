mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      name = "projects/example-project/serviceAccounts/example-workload@example-project.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_iam_workload_identity_pool" {
    defaults = {
      name = "projects/123456789/locations/global/workloadIdentityPools/example-workload-runtime"
    }
  }
}

variables {
  project_id   = "example-project"
  name         = "example-workload"
  tenant_id    = "00000000-0000-0000-0000-000000000001"
  principal_id = "00000000-0000-0000-0000-000000000002"
  issuer       = "https://sts.windows.net/00000000-0000-0000-0000-000000000001/"
  audience     = "api://00000000-0000-0000-0000-000000000003"
  role_value   = "Access.Workload"
  role = {
    id          = "exampleWorkloadAccess"
    title       = "Example workload access"
    description = "Read objects in the configured project."
    permissions = ["storage.objects.get"]
  }
}

run "restrict_runtime_identity" {
  command = plan
  assert {
    condition     = toset(google_iam_workload_identity_pool_provider.azure.oidc[0].allowed_audiences) == toset([var.audience]) && strcontains(google_iam_workload_identity_pool_provider.azure.attribute_condition, var.principal_id) && strcontains(google_iam_workload_identity_pool_provider.azure.attribute_condition, var.tenant_id) && strcontains(google_iam_workload_identity_pool_provider.azure.attribute_condition, "'${var.role_value}' in assertion.roles")
    error_message = "Runtime trust must require dedicated audience, tenant, identity and app role."
  }
  assert {
    condition     = toset(google_project_iam_custom_role.access.permissions) == var.role.permissions && google_project_iam_custom_role.access.role_id == var.role.id && google_project_iam_custom_role.access.title == var.role.title && google_project_iam_custom_role.access.description == var.role.description
    error_message = "The role must preserve the caller-defined metadata and exact permission set."
  }
}

run "restrict_native_service_account" {
  command = apply

  variables {
    issuer       = "https://example.oic.prod-aks.azure.com/issuer/"
    subject      = "system:serviceaccount:litellm:litellm"
    tenant_id    = null
    principal_id = null
    role_value   = null
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.azure.attribute_mapping["google.subject"] == "assertion.sub" && google_iam_workload_identity_pool_provider.azure.attribute_condition == "assertion.sub == 'system:serviceaccount:litellm:litellm'" && endswith(google_service_account_iam_member.azure.member, "/subject/system:serviceaccount:litellm:litellm")
    error_message = "AKS trust must bind exactly one native ServiceAccount without Entra placeholder claims."
  }
}

run "reject_incomplete_entra_contract" {
  command = plan
  variables {
    tenant_id = null
  }
  expect_failures = [google_iam_workload_identity_pool_provider.azure]
}
