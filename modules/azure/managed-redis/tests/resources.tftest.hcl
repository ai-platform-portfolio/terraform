mock_provider "azurerm" {
  mock_resource "azurerm_managed_redis" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Cache/redisEnterprise/example-service" }
  }
  mock_resource "azurerm_private_endpoint" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Network/privateEndpoints/example" }
  }
  mock_resource "azurerm_role_assignment" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Cache/redisEnterprise/example-service/providers/Microsoft.Authorization/roleAssignments/00000000-0000-0000-0000-000000000002" }
  }
  mock_resource "azurerm_managed_redis_access_policy_assignment" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Cache/redisEnterprise/example-service/databases/default/accessPolicyAssignments/00000000-0000-0000-0000-000000000002" }
  }
}

variables {
  name                = "example-service"
  resource_group_name = "example-rg"
  location            = "uksouth"
  sku_name            = "Balanced_B0"
}

run "private_keyless_defaults" {
  command = plan

  assert {
    condition     = azurerm_managed_redis.this.public_network_access == "Disabled" && !azurerm_managed_redis.this.default_database[0].access_keys_authentication_enabled && azurerm_managed_redis.this.default_database[0].client_protocol == "Encrypted"
    error_message = "Default access must remain private and keyless."
  }

  assert {
    condition     = length(azurerm_private_endpoint.this) == 0
    error_message = "Endpoints require explicit caller intent."
  }
}

run "multiple_children_and_endpoints" {
  command = apply

  variables {
    private_endpoints = {
      workload = {
        subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Network/virtualNetworks/example/subnets/private"
        private_dns_zone_ids = ["/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Network/privateDnsZones/example.internal"]
      }
      secondary = {
        name                 = "custom-endpoint"
        location             = "westeurope"
        subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Network/virtualNetworks/example/subnets/private"
        is_manual_connection = true
        request_message      = "Example approval request"
      }
    }
    access_policy_assignments = {
      worker   = { object_id = "00000000-0000-0000-0000-000000000002" }
      observer = { object_id = "00000000-0000-0000-0000-000000000003" }
    }
    default_database = { modules = { RedisJSON = {}, RediSearch = {} } }
  }

  assert {
    condition     = length(azurerm_private_endpoint.this) == 2 && azurerm_private_endpoint.this["workload"].name == "example-service-workload" && azurerm_private_endpoint.this["secondary"].name == "custom-endpoint"
    error_message = "Endpoint map keys must preserve independent names and caller overrides."
  }

  assert {
    condition     = alltrue([for endpoint in values(azurerm_private_endpoint.this) : endpoint.private_service_connection[0].private_connection_resource_id == azurerm_managed_redis.this.id])
    error_message = "Every endpoint must target this parent."
  }

  assert {
    condition     = length(azurerm_private_endpoint.this["workload"].private_dns_zone_group) == 1 && length(azurerm_private_endpoint.this["secondary"].private_dns_zone_group) == 0 && azurerm_private_endpoint.this["secondary"].private_service_connection[0].is_manual_connection
    error_message = "DNS grouping and approval mode must follow endpoint intent."
  }

  assert {
    condition     = length(azurerm_managed_redis_access_policy_assignment.this) == 2 && azurerm_managed_redis_access_policy_assignment.this["worker"].managed_redis_id == azurerm_managed_redis.this.id && length(azurerm_managed_redis.this.default_database[0].module) == 2
    error_message = "Access assignments and Redis modules must follow caller maps."
  }
}

run "reject_conflicting_persistence" {
  command = plan

  variables {
    default_database = { persistence_append_only_file_backup_frequency = "1s", persistence_redis_database_backup_frequency = "1h" }
  }

  expect_failures = [azurerm_managed_redis.this]
}

run "public_ha_and_persistence_opt_in" {
  command = plan

  variables {
    public_network_access     = "Enabled"
    high_availability_enabled = true
    default_database          = { persistence_redis_database_backup_frequency = "1h" }
  }

  assert {
    condition     = azurerm_managed_redis.this.public_network_access == "Enabled" && azurerm_managed_redis.this.high_availability_enabled
    error_message = "Caller overrides must be respected."
  }
}
