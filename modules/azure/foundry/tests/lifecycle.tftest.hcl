mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = { subscription_id = "00000000-0000-0000-0000-000000000001" }
  }
}
mock_provider "azapi" {}

variables {
  name                       = "example-models"
  resource_group_name        = "example-rg"
  location                   = "UK West"
  managed_identity_id        = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/example"
  private_endpoint_location  = "uksouth"
  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Network/virtualNetworks/example/subnets/private"
  private_dns_zone_ids = [for name in ["cognitiveservices", "openai", "services.ai"] :
    "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Network/privateDnsZones/privatelink.${name}.azure.com"
  ]
}

run "private_account_and_scoped_destroy_purge" {
  command = plan

  assert {
    condition = (
      azapi_resource.account.body.properties.disableLocalAuth &&
      azapi_resource.account.body.properties.publicNetworkAccess == "Disabled" &&
      azapi_resource.account.body.properties.networkAcls.defaultAction == "Deny" &&
      azapi_resource.account.body.properties.allowProjectManagement &&
      azapi_resource.account.body.identity.type == "UserAssigned" &&
      contains(keys(azapi_resource.account.body.identity.userAssignedIdentities), var.managed_identity_id)
    )
    error_message = "The AzAPI account must preserve private, keyless, project-enabled defaults and the supplied identity."
  }

  assert {
    condition = (
      azapi_resource_action.purge[0].when == "destroy" &&
      azapi_resource_action.purge[0].method == "DELETE" &&
      azapi_resource_action.purge[0].resource_id == "/subscriptions/00000000-0000-0000-0000-000000000001/providers/Microsoft.CognitiveServices/locations/ukwest/resourceGroups/example-rg/deletedAccounts/example-models" &&
      azapi_resource_action.purge[0].ignore_not_found
    )
    error_message = "Purge must be destroy-only, idempotent and scoped to the account's actual region, group and name."
  }

  assert {
    condition = (
      length(regexall(azapi_resource.account.retry.error_message_regex[0], "RequestConflict\nCannot modify resource because the resource entity provisioning state is not terminal.")) == 1 &&
      length(regexall(azapi_resource.account.retry.error_message_regex[0], "RequestConflict: account name is already in use")) == 0 &&
      length(regexall(azapi_resource.account.retry.error_message_regex[0], "AuthorizationFailed: access denied")) == 0
    )
    error_message = "Only the observed non-terminal HTTP conflict is eligible for the custom retry."
  }
}

run "caller_can_retain_deleted_account" {
  command = plan

  variables { purge_on_destroy = false }

  assert {
    condition     = length(azapi_resource_action.purge) == 0
    error_message = "Retention intent must disable the purge action."
  }
}

run "caller_settings_and_delete_budget" {
  command = plan

  variables {
    account_settings = {
      custom_subdomain_name         = "example-custom"
      public_network_access_enabled = true
      local_auth_enabled            = true
    }
    timeouts = { create = "20m", update = "15m", delete = "12m" }
  }

  assert {
    condition = (
      !azapi_resource.account.body.properties.disableLocalAuth &&
      azapi_resource.account.body.properties.publicNetworkAccess == "Enabled" &&
      output.openai_endpoint == "https://example-custom.openai.azure.com/" &&
      azapi_resource.account.timeouts.delete == "12m" &&
      azapi_resource_action.purge[0].timeouts.create == "12m" &&
      azapi_resource_action.purge[0].timeouts.delete == "12m"
    )
    error_message = "Caller settings must translate correctly; purge must use the caller's delete budget through AzAPI's action timeout."
  }
}
