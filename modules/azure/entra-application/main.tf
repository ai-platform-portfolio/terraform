terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

resource "azuread_application" "this" {
  display_name            = var.display_name
  sign_in_audience        = var.sign_in_audience
  owners                  = var.owners
  group_membership_claims = var.group_membership_claims

  web {
    redirect_uris = var.web_redirect_uris
  }

  public_client {
    redirect_uris = var.public_client_redirect_uris
  }
}

resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id
  owners    = var.owners
}

resource "azuread_application_federated_identity_credential" "this" {
  for_each       = var.federated_credentials
  application_id = azuread_application.this.id
  display_name   = each.key
  audiences      = each.value.audiences
  issuer         = each.value.issuer
  subject        = each.value.subject
}
