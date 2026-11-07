terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.13, < 3.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81, < 5.0"
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  account_location   = lower(replace(var.location, " ", ""))
  resource_group_id  = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  deleted_account_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.CognitiveServices/locations/${local.account_location}/resourceGroups/${var.resource_group_name}/deletedAccounts/${var.name}"

  account_retry = {
    error_message_regex  = ["(?s)RequestConflict.*provisioning state is not terminal"]
    interval_seconds     = 5
    max_interval_seconds = 30
  }
}

resource "azapi_resource" "account" {
  # Reverse destroy order: children -> account -> purge. The purge action makes
  # no API request on creation and must not reference account.id (a cycle).
  depends_on = [azapi_resource_action.purge]

  type      = "Microsoft.CognitiveServices/accounts@2026-03-01"
  name      = var.name
  parent_id = local.resource_group_id
  location  = local.account_location
  tags      = var.tags

  body = {
    identity = merge({ type = var.identity_type }, strcontains(var.identity_type, "UserAssigned") ? {
      userAssignedIdentities = { (var.managed_identity_id) = {} }
    } : {})
    kind = var.account_settings.kind
    sku  = { name = var.sku_name }
    properties = {
      allowProjectManagement = var.account_settings.project_management_enabled
      customSubDomainName    = coalesce(var.account_settings.custom_subdomain_name, var.name)
      disableLocalAuth       = !var.account_settings.local_auth_enabled
      publicNetworkAccess    = var.account_settings.public_network_access_enabled ? "Enabled" : "Disabled"
      networkAcls = {
        defaultAction = var.network_acls.default_action
        bypass        = var.network_acls.bypass
      }
    }
  }

  retry = local.account_retry

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
}

resource "azapi_resource_action" "purge" {
  count = var.purge_on_destroy ? 1 : 0

  type             = "Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts@2026-03-01"
  resource_id      = local.deleted_account_id
  method           = "DELETE"
  when             = "destroy"
  ignore_not_found = true
  retry            = local.account_retry

  timeouts {
    # AzAPI 2.13's action executor uses create even for a destroy-time action.
    create = var.timeouts.delete
    delete = var.timeouts.delete
  }
}

resource "azurerm_cognitive_account_project" "this" {
  for_each             = var.projects
  name                 = each.key
  cognitive_account_id = azapi_resource.account.id
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

resource "azapi_resource" "private_endpoint" {
  depends_on = [azurerm_cognitive_account_project.this, azurerm_cognitive_deployment.this]

  type      = "Microsoft.Network/privateEndpoints@2025-01-01"
  name      = coalesce(var.private_endpoint_settings.name, "${var.name}${var.private_endpoint_settings.name_suffix}")
  parent_id = local.resource_group_id
  location  = var.private_endpoint_location
  tags      = var.tags

  body = {
    properties = {
      customNetworkInterfaceName = ""
      ipConfigurations           = []
      subnet                     = { id = var.private_endpoint_subnet_id }
      privateLinkServiceConnections = var.private_endpoint_settings.is_manual_connection ? [] : [{
        name = coalesce(var.private_endpoint_settings.connection_name, var.name)
        properties = {
          privateLinkServiceId = azapi_resource.account.id
          groupIds             = var.private_endpoint_settings.subresource_names
        }
      }]
      manualPrivateLinkServiceConnections = var.private_endpoint_settings.is_manual_connection ? [{
        name = coalesce(var.private_endpoint_settings.connection_name, var.name)
        properties = {
          privateLinkServiceId = azapi_resource.account.id
          groupIds             = var.private_endpoint_settings.subresource_names
        }
      }] : []
    }
  }

  # Retry the known HTTP readiness error, not arbitrary failed operations.
  retry = { error_message_regex = ["Account.*state Accepted"] }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
}

resource "azapi_resource" "private_dns_zone_group" {
  type      = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01"
  name      = var.private_endpoint_settings.dns_zone_group_name
  parent_id = azapi_resource.private_endpoint.id

  body = {
    properties = {
      privateDnsZoneConfigs = [for id in var.private_dns_zone_ids : {
        name       = basename(id)
        properties = { privateDnsZoneId = id }
      }]
    }
  }
}

resource "azurerm_cognitive_deployment" "this" {
  depends_on = [azurerm_cognitive_account_project.this]

  for_each               = var.deployments
  name                   = each.key
  cognitive_account_id   = azapi_resource.account.id
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

resource "azurerm_role_assignment" "this" {
  for_each             = var.role_assignments
  scope                = azapi_resource.account.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}
