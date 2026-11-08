mock_provider "azurerm" {
  mock_resource "azurerm_eventgrid_domain" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.EventGrid/domains/example-service" }
  }
  mock_resource "azurerm_private_endpoint" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Network/privateEndpoints/example" }
  }
  mock_resource "azurerm_role_assignment" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.EventGrid/domains/example-service/providers/Microsoft.Authorization/roleAssignments/00000000-0000-0000-0000-000000000002" }
  }
  mock_resource "azurerm_eventgrid_domain_topic" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.EventGrid/domains/example-service/topics/events" }
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
    condition     = !azurerm_eventgrid_domain.this.public_network_access_enabled && !azurerm_eventgrid_domain.this.local_auth_enabled
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
    identity = { type = "SystemAssigned" }
    topics   = { events = {}, audit = { name = "audit-events" } }
    event_subscriptions = {
      worker = {
        topic_key                            = "events"
        eventhub_endpoint_id                 = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.EventHub/namespaces/events/eventhubs/events"
        delivery_identity                    = { type = "SystemAssigned" }
        subject_filter                       = { subject_begins_with = "/orders/" }
        advanced_filter                      = { string_in = [{ key = "data.kind", values = ["order"] }], number_greater_than = [{ key = "data.amount", value = 10 }] }
        storage_blob_dead_letter_destination = { storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Storage/storageAccounts/examplestorage", storage_blob_container_name = "deadletter" }
        dead_letter_identity                 = { type = "SystemAssigned" }
      }
      domain = { webhook_endpoint = { url = "https://example.com/events" } }
    }
  }

  assert {
    condition     = length(azurerm_private_endpoint.this) == 2 && azurerm_private_endpoint.this["workload"].name == "example-service-workload" && azurerm_private_endpoint.this["secondary"].name == "custom-endpoint"
    error_message = "Endpoint map keys must preserve independent names and caller overrides."
  }

  assert {
    condition     = alltrue([for endpoint in values(azurerm_private_endpoint.this) : endpoint.private_service_connection[0].private_connection_resource_id == azurerm_eventgrid_domain.this.id])
    error_message = "Every endpoint must target this parent."
  }

  assert {
    condition     = length(azurerm_private_endpoint.this["workload"].private_dns_zone_group) == 1 && length(azurerm_private_endpoint.this["secondary"].private_dns_zone_group) == 0 && azurerm_private_endpoint.this["secondary"].private_service_connection[0].is_manual_connection
    error_message = "DNS grouping and approval mode must follow endpoint intent."
  }

  assert {
    condition     = length(azurerm_role_assignment.this) == 2 && alltrue([for assignment in values(azurerm_role_assignment.this) : assignment.scope == azurerm_eventgrid_domain.this.id])
    error_message = "Role assignments must remain scoped to this parent."
  }

  assert {
    condition     = azurerm_eventgrid_event_subscription.this["worker"].scope == azurerm_eventgrid_domain_topic.this["events"].id && azurerm_eventgrid_event_subscription.this["domain"].scope == azurerm_eventgrid_domain.this.id
    error_message = "Subscriptions must preserve topic/domain scope."
  }

  assert {
    condition     = !azurerm_eventgrid_domain.this.auto_delete_topic_with_last_subscription && !azurerm_eventgrid_domain.this.auto_create_topic_with_first_subscription
    error_message = "Explicit topic lifecycles must be independent of subscriptions."
  }
}

run "reject_multiple_destinations" {
  command = plan

  variables {
    event_subscriptions = {
      invalid = { webhook_endpoint = { url = "https://example.com/events" }, eventhub_endpoint_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.EventHub/namespaces/events/eventhubs/events" }
    }
  }

  expect_failures = [azurerm_eventgrid_domain.this]
}

run "public_opt_in" {
  command = plan

  variables {
    public_network_access_enabled = true
    local_auth_enabled            = true
  }

  assert {
    condition     = azurerm_eventgrid_domain.this.public_network_access_enabled && azurerm_eventgrid_domain.this.local_auth_enabled
    error_message = "Caller overrides must be respected."
  }
}
