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

resource "azuread_group" "this" {
  display_name            = var.display_name
  description             = var.description
  security_enabled        = true
  mail_enabled            = false
  prevent_duplicate_names = true
  owners                  = var.owners
  members                 = var.members
}

resource "azurerm_role_assignment" "this" {
  for_each             = var.role_assignments
  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = azuread_group.this.object_id
  principal_type       = "Group"
}
