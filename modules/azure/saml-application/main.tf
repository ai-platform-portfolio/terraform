terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

data "azuread_application_template" "this" {
  display_name = var.template_name
}

resource "azuread_application" "this" {
  display_name            = var.display_name
  template_id             = data.azuread_application_template.this.template_id
  owners                  = var.owners
  identifier_uris         = [var.service_provider.entity_id]
  prevent_duplicate_names = true

  web {
    redirect_uris = [var.service_provider.acs_url]
    homepage_url  = var.service_provider.start_url
  }

  lifecycle {
    # Preserve gallery-owned role IDs and API scopes across subsequent plans.
    ignore_changes = [app_role, api]
  }
}

resource "azuread_service_principal" "this" {
  client_id                     = azuread_application.this.client_id
  owners                        = var.owners
  preferred_single_sign_on_mode = "saml"
  app_role_assignment_required  = true

  # Instantiating a gallery application also creates its principal. This resource
  # deliberately owns that newly created principal, not an unrelated existing app.
  use_existing = true
}

resource "azuread_service_principal_token_signing_certificate" "this" {
  service_principal_id = azuread_service_principal.this.id
}

resource "azuread_app_role_assignment" "this" {
  for_each = var.assignments

  principal_object_id = each.value.principal_object_id
  resource_object_id  = azuread_service_principal.this.object_id
  app_role_id = one([
    for role in azuread_service_principal.this.app_roles : role.id
    if role.display_name == each.value.role_name && role.enabled && contains(role.allowed_member_types, "User")
  ])

  lifecycle {
    precondition {
      condition     = length([for role in azuread_service_principal.this.app_roles : role.id if role.display_name == each.value.role_name && role.enabled && contains(role.allowed_member_types, "User")]) == 1
      error_message = "Select exactly one enabled gallery user role by display name."
    }
  }
}
