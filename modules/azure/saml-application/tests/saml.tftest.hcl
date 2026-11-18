mock_provider "azuread" {
  mock_data "azuread_application_template" {
    defaults = { template_id = "00000000-0000-0000-0000-000000000004" }
  }

  mock_resource "azuread_application" {
    defaults = { client_id = "00000000-0000-0000-0000-000000000005" }
  }
}

override_resource {
  target = azuread_service_principal.this
  values = {
    id        = "/servicePrincipals/00000000-0000-0000-0000-000000000006"
    object_id = "00000000-0000-0000-0000-000000000006"
    app_roles = [{
      id          = "00000000-0000-0000-0000-000000000001", display_name = "User", value = "User",
      description = "Gallery user", enabled = true, allowed_member_types = ["User"]
    }]
  }
}

variables {
  display_name  = "Example SAML"
  template_name = "Example Gallery"
  owners        = ["00000000-0000-0000-0000-000000000002"]
  service_provider = {
    entity_id = "https://service.example.test/entity"
    acs_url   = "https://service.example.test/acs"
    start_url = "https://service.example.test/"
  }
  assignments = { operator = { principal_object_id = "00000000-0000-0000-0000-000000000003", role_name = "User" } }
}

run "assigned_saml_access" {
  command = apply

  assert {
    condition     = azuread_service_principal.this.preferred_single_sign_on_mode == "saml" && azuread_service_principal.this.app_role_assignment_required
    error_message = "SAML access must require an explicit assignment."
  }

  assert {
    condition     = azuread_application.this.identifier_uris == toset([var.service_provider.entity_id]) && azuread_application.this.web[0].redirect_uris == toset([var.service_provider.acs_url])
    error_message = "The app must use only the declared service provider entity and callback."
  }

  assert {
    condition     = azuread_app_role_assignment.this["operator"].app_role_id == "00000000-0000-0000-0000-000000000001" && azuread_app_role_assignment.this["operator"].principal_object_id == var.assignments.operator.principal_object_id
    error_message = "Only the selected user's enabled gallery role should be assigned."
  }
}

run "reject_unknown_gallery_role" {
  command = plan
  variables { assignments = { operator = { principal_object_id = "00000000-0000-0000-0000-000000000003", role_name = "Administrator" } } }
  expect_failures = [azuread_app_role_assignment.this["operator"]]
}
