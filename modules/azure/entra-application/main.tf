terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azuread_application" "this" {
  display_name                   = var.display_name
  description                    = var.description
  sign_in_audience               = var.sign_in_audience
  owners                         = var.owners
  group_membership_claims        = var.group_membership_claims
  identifier_uris                = var.identifier_uris
  prevent_duplicate_names        = var.prevent_duplicate_names
  fallback_public_client_enabled = var.fallback_public_client_enabled

  dynamic "web" {
    for_each = var.web == null ? [] : [var.web]
    content {
      redirect_uris = web.value.redirect_uris
      homepage_url  = web.value.homepage_url
      logout_url    = web.value.logout_url

      implicit_grant {
        access_token_issuance_enabled = web.value.implicit_grant.access_token_issuance_enabled
        id_token_issuance_enabled     = web.value.implicit_grant.id_token_issuance_enabled
      }
    }
  }

  dynamic "single_page_application" {
    for_each = length(var.spa_redirect_uris) == 0 ? [] : [var.spa_redirect_uris]
    content {
      redirect_uris = single_page_application.value
    }
  }

  dynamic "public_client" {
    for_each = length(var.public_client_redirect_uris) == 0 ? [] : [var.public_client_redirect_uris]
    content {
      redirect_uris = public_client.value
    }
  }

  dynamic "api" {
    for_each = var.api == null ? [] : [var.api]
    content {
      requested_access_token_version = api.value.requested_access_token_version
      known_client_applications      = api.value.known_client_applications

      dynamic "oauth2_permission_scope" {
        for_each = api.value.scopes
        content {
          id                         = oauth2_permission_scope.value.id
          value                      = oauth2_permission_scope.key
          type                       = oauth2_permission_scope.value.type
          enabled                    = oauth2_permission_scope.value.enabled
          admin_consent_display_name = oauth2_permission_scope.value.admin_consent_display_name
          admin_consent_description  = oauth2_permission_scope.value.admin_consent_description
          user_consent_display_name  = oauth2_permission_scope.value.user_consent_display_name
          user_consent_description   = oauth2_permission_scope.value.user_consent_description
        }
      }
    }
  }

  dynamic "app_role" {
    for_each = var.app_roles
    content {
      id                   = app_role.value.id
      value                = app_role.key
      display_name         = app_role.value.display_name
      description          = app_role.value.description
      allowed_member_types = app_role.value.allowed_member_types
      enabled              = app_role.value.enabled
    }
  }

  # Declaring requested permissions does not grant consent.
  dynamic "required_resource_access" {
    for_each = var.required_resource_access
    content {
      resource_app_id = required_resource_access.value.resource_app_id
      dynamic "resource_access" {
        for_each = required_resource_access.value.permissions
        content {
          id   = resource_access.value.id
          type = resource_access.value.type
        }
      }
    }
  }

  dynamic "optional_claims" {
    for_each = var.optional_claims == null ? [] : [var.optional_claims]
    content {
      dynamic "id_token" {
        for_each = optional_claims.value.id_token
        content {
          name                  = id_token.value.name
          source                = id_token.value.source
          essential             = id_token.value.essential
          additional_properties = id_token.value.additional_properties
        }
      }

      dynamic "access_token" {
        for_each = optional_claims.value.access_token
        content {
          name                  = access_token.value.name
          source                = access_token.value.source
          essential             = access_token.value.essential
          additional_properties = access_token.value.additional_properties
        }
      }

      dynamic "saml2_token" {
        for_each = optional_claims.value.saml2_token
        content {
          name                  = saml2_token.value.name
          source                = saml2_token.value.source
          essential             = saml2_token.value.essential
          additional_properties = saml2_token.value.additional_properties
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.api == null ? true : length(setintersection(toset(keys(var.app_roles)), toset(keys(var.api.scopes)))) == 0
      error_message = "App role values and exposed API scope values must be distinct."
    }

    precondition {
      condition     = !contains(["AzureADandPersonalMicrosoftAccount", "PersonalMicrosoftAccount"], var.sign_in_audience) || try(var.api.requested_access_token_version, 1) == 2
      error_message = "Applications accepting personal Microsoft accounts require api.requested_access_token_version = 2."
    }
  }
}

resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  owners                       = var.owners
  account_enabled              = var.service_principal.account_enabled
  app_role_assignment_required = var.service_principal.assignment_required
}

resource "azuread_application_federated_identity_credential" "this" {
  for_each       = var.federated_credentials
  application_id = azuread_application.this.id
  display_name   = each.key
  description    = each.value.description
  audiences      = each.value.audiences
  issuer         = each.value.issuer
  subject        = each.value.subject
}

# Inbound access: assign this application's roles to users, groups or clients.
resource "azuread_app_role_assignment" "this" {
  for_each            = var.app_role_assignments
  principal_object_id = each.value.principal_object_id
  resource_object_id  = azuread_service_principal.this.object_id
  app_role_id         = each.value.role == null ? "00000000-0000-0000-0000-000000000000" : lookup(azuread_application.this.app_role_ids, each.value.role, "00000000-0000-0000-0000-000000000000")

  lifecycle {
    precondition {
      condition     = each.value.role == null ? length(var.app_roles) == 0 : contains(keys(var.app_roles), each.value.role)
      error_message = "Select a declared app role value; omit role only when the application exposes no roles."
    }
  }
}

# Outbound access: explicitly consent application permissions on other APIs.
resource "azuread_app_role_assignment" "api" {
  for_each            = var.application_permission_grants
  principal_object_id = azuread_service_principal.this.object_id
  resource_object_id  = each.value.resource_principal_id
  app_role_id         = each.value.app_role_id
}

resource "azuread_service_principal_delegated_permission_grant" "this" {
  for_each                             = var.delegated_permission_grants
  service_principal_object_id          = azuread_service_principal.this.object_id
  resource_service_principal_object_id = each.value.resource_principal_id
  claim_values                         = each.value.scopes
  user_object_id                       = each.value.user_object_id
}

resource "azurerm_role_assignment" "this" {
  for_each             = var.role_assignments
  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = azuread_service_principal.this.object_id
  principal_type       = "ServicePrincipal"
}
