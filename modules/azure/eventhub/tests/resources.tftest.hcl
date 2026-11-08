mock_provider "azurerm" {
  mock_resource "azurerm_eventhub_namespace" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.EventHub/namespaces/example-service" }
  }
  mock_resource "azurerm_private_endpoint" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Network/privateEndpoints/example" }
  }
  mock_resource "azurerm_role_assignment" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.EventHub/namespaces/example-service/providers/Microsoft.Authorization/roleAssignments/00000000-0000-0000-0000-000000000002" }
  }
  mock_resource "azurerm_eventhub" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.EventHub/namespaces/example-service/eventhubs/events" }
  }
}

variables {
  name                = "example-service"
  resource_group_name = "example-rg"
  location            = "uksouth"
}

run "private_keyless_defaults" {
  command = plan

  assert {
    condition     = !azurerm_eventhub_namespace.this.public_network_access_enabled && !azurerm_eventhub_namespace.this.local_authentication_enabled
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
    role_assignments = {
      sender   = { principal_id = "00000000-0000-0000-0000-000000000002", role_definition_name = "Reader" }
      observer = { principal_id = "00000000-0000-0000-0000-000000000003", role_definition_name = "Reader" }
    }
    identity = { type = "UserAssigned", identity_ids = ["/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/capture"] }
    eventhubs = {
      events = {}
      audit = {
        partition_count = 4
        capture_description = {
          destination = { storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Storage/storageAccounts/examplestorage", blob_container_name = "capture", storage_authentication_type = "UserAssigned", storage_authentication_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/capture" }
        }
      }
    }
    consumer_groups  = { worker = { eventhub_key = "events" }, audit = { eventhub_key = "audit", name = "audit-reader" } }
    network_rulesets = { ip_rules = { operator = { ip_mask = "203.0.113.8" } } }
  }

  assert {
    condition     = length(azurerm_private_endpoint.this) == 2 && azurerm_private_endpoint.this["workload"].name == "example-service-workload" && azurerm_private_endpoint.this["secondary"].name == "custom-endpoint"
    error_message = "Endpoint map keys must preserve independent names and caller overrides."
  }

  assert {
    condition     = alltrue([for endpoint in values(azurerm_private_endpoint.this) : endpoint.private_service_connection[0].private_connection_resource_id == azurerm_eventhub_namespace.this.id])
    error_message = "Every endpoint must target this parent."
  }

  assert {
    condition     = length(azurerm_private_endpoint.this["workload"].private_dns_zone_group) == 1 && length(azurerm_private_endpoint.this["secondary"].private_dns_zone_group) == 0 && azurerm_private_endpoint.this["secondary"].private_service_connection[0].is_manual_connection
    error_message = "DNS grouping and approval mode must follow endpoint intent."
  }

  assert {
    condition     = length(azurerm_role_assignment.this) == 2 && alltrue([for assignment in values(azurerm_role_assignment.this) : assignment.scope == azurerm_eventhub_namespace.this.id])
    error_message = "Role assignments must remain scoped to this parent."
  }

  assert {
    condition     = azurerm_eventhub.this["events"].namespace_id == azurerm_eventhub_namespace.this.id && azurerm_eventhub_consumer_group.this["audit"].eventhub_name == azurerm_eventhub.this["audit"].name
    error_message = "Event hubs and consumer groups must reference the declared parent."
  }

  assert {
    condition     = azurerm_eventhub.this["audit"].capture_description[0].destination[0].storage_authentication_type == "UserAssigned" && azurerm_eventhub.this["events"].retention_description[0].retention_time_in_hours == 24
    error_message = "Capture must preserve identity intent and normal retention must be explicit."
  }
}

run "public_auto_inflate_opt_in" {
  command = plan

  variables {
    public_network_access_enabled = true
    auto_inflate_enabled          = true
    maximum_throughput_units      = 4
  }

  assert {
    condition     = azurerm_eventhub_namespace.this.public_network_access_enabled && azurerm_eventhub_namespace.this.maximum_throughput_units == 4
    error_message = "Namespace overrides must be respected."
  }
}

run "reject_basic_private_endpoint" {
  command = plan

  variables {
    sku = "Basic"
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
  }

  expect_failures = [azurerm_eventhub_namespace.this]
}

run "reject_capture_without_namespace_identity" {
  command = plan

  variables {
    eventhubs = {
      events = {
        capture_description = {
          destination = {
            storage_account_id  = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Storage/storageAccounts/examplestorage"
            blob_container_name = "capture"
          }
        }
      }
    }
  }

  expect_failures = [azurerm_eventhub_namespace.this]
}
