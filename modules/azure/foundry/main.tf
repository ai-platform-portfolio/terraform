terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81, < 5.0"
    }
  }
}

resource "azurerm_cognitive_account" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  kind                          = var.account_settings.kind
  sku_name                      = var.sku_name
  custom_subdomain_name         = coalesce(var.account_settings.custom_subdomain_name, var.name)
  project_management_enabled    = var.account_settings.project_management_enabled
  public_network_access_enabled = var.account_settings.public_network_access_enabled
  local_auth_enabled            = var.account_settings.local_auth_enabled
  tags                          = var.tags

  identity {
    type         = var.identity_type
    identity_ids = [var.managed_identity_id]
  }

  network_acls {
    default_action = var.network_acls.default_action
    bypass         = var.network_acls.bypass
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
}

resource "azurerm_cognitive_account_project" "this" {
  for_each             = var.projects
  name                 = each.key
  cognitive_account_id = azurerm_cognitive_account.this.id
  location             = var.location
  display_name         = each.value.display_name
  description          = each.value.description
  tags                 = var.tags

  identity {
    type         = var.identity_type
    identity_ids = [var.managed_identity_id]
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
}

resource "azurerm_private_endpoint" "this" {
  depends_on = [azurerm_cognitive_account_project.this, azurerm_cognitive_deployment.this]

  name                = coalesce(var.private_endpoint_settings.name, "${var.name}${var.private_endpoint_settings.name_suffix}")
  resource_group_name = var.resource_group_name
  location            = var.private_endpoint_location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = coalesce(var.private_endpoint_settings.connection_name, var.name)
    private_connection_resource_id = azurerm_cognitive_account.this.id
    subresource_names              = var.private_endpoint_settings.subresource_names
    is_manual_connection           = var.private_endpoint_settings.is_manual_connection
  }

  private_dns_zone_group {
    name                 = var.private_endpoint_settings.dns_zone_group_name
    private_dns_zone_ids = var.private_dns_zone_ids
  }
}

resource "azurerm_cognitive_deployment" "this" {
  depends_on = [azurerm_cognitive_account_project.this]

  for_each               = var.deployments
  name                   = each.key
  cognitive_account_id   = azurerm_cognitive_account.this.id
  version_upgrade_option = each.value.version_upgrade_option
  rai_policy_name        = each.value.rai_policy_name

  model {
    format  = each.value.format
    name    = each.value.model_name
    version = each.value.model_version
  }

  sku {
    name     = each.value.sku_name
    capacity = each.value.capacity
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  lifecycle {
    precondition {
      condition     = contains(var.allowed_deployment_skus, each.value.sku_name)
      error_message = "The deployment SKU is outside the approved processing scope."
    }
  }
}

resource "azurerm_role_assignment" "inference" {
  scope                            = azurerm_cognitive_account.this.id
  role_definition_name             = var.inference_role_name
  principal_id                     = var.inference_principal_id
  principal_type                   = var.inference_principal_type
  skip_service_principal_aad_check = var.skip_service_principal_aad_check
}
