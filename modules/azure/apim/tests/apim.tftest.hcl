mock_provider "azurerm" {}
mock_provider "azapi" {}

variables {
  managed_identity_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/shared"
  name                       = "example-model-gateway"
  resource_group_name        = "example-rg"
  location                   = "ukwest"
  publisher_name             = "Example publisher"
  publisher_email            = "publisher@example.invalid"
  sku_name                   = "StandardV2_1"
  integration_subnet_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/virtualNetworks/example/subnets/apim"
  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/virtualNetworks/example/subnets/private-endpoints"
  private_dns_zone_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azure-api.net"
}

run "private_gateway_with_workload_identity" {
  command = plan

  assert {
    condition = (
      azurerm_api_management.this.sku_name == "StandardV2_1" &&
      azurerm_api_management.this.virtual_network_type == "External" &&
      azurerm_api_management.this.virtual_network_configuration[0].subnet_id == var.integration_subnet_id &&
      azurerm_api_management.this.identity[0].type == "UserAssigned" &&
      contains(azurerm_api_management.this.identity[0].identity_ids, var.managed_identity_id)
    )
    error_message = "Standard v2 must use the supplied integration subnet and managed identity."
  }
  assert {
    condition = (
      contains(azurerm_private_endpoint.this.private_service_connection[0].subresource_names, "Gateway") &&
      azurerm_private_endpoint.this.subnet_id == var.private_endpoint_subnet_id &&
      azapi_update_resource.private_access.body.properties.publicNetworkAccess == "Disabled"
    )
    error_message = "Gateway private access must use the separate subnet and disable public access."
  }
}

run "unsupported_tier_is_rejected" {
  command = plan
  variables {
    sku_name = "Developer_1"
  }
  expect_failures = [var.sku_name]
}

run "shared_subnet_is_rejected" {
  command = plan
  variables {
    private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/virtualNetworks/example/subnets/apim"
  }
  expect_failures = [var.private_endpoint_subnet_id]
}

run "caller_can_override_timeouts" {
  command = plan
  variables {
    timeouts = { create = "4h", update = "2h", delete = "1h" }
  }
  assert {
    condition     = azurerm_api_management.this.timeouts.create == "4h" && azurerm_api_management.this.timeouts.update == "2h" && azurerm_api_management.this.timeouts.delete == "1h" && azapi_update_resource.private_access.timeouts.create == "4h" && azapi_update_resource.private_access.timeouts.update == "2h"
    error_message = "Both APIM operations and the ordered private-access update must honour caller timeouts."
  }
}
