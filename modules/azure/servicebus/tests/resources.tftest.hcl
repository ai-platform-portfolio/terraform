mock_provider "azurerm" {
  mock_resource "azurerm_servicebus_namespace" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.ServiceBus/namespaces/example-service" }
  }
  mock_resource "azurerm_private_endpoint" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.Network/privateEndpoints/example" }
  }
  mock_resource "azurerm_role_assignment" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.ServiceBus/namespaces/example-service/providers/Microsoft.Authorization/roleAssignments/00000000-0000-0000-0000-000000000002" }
  }
  mock_resource "azurerm_servicebus_topic" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.ServiceBus/namespaces/example-service/topics/events" }
  }
  mock_resource "azurerm_servicebus_subscription" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example-rg/providers/Microsoft.ServiceBus/namespaces/example-service/topics/events/subscriptions/worker" }
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
    condition     = !azurerm_servicebus_namespace.this.public_network_access_enabled && !azurerm_servicebus_namespace.this.local_auth_enabled
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
    queues        = { jobs = {}, retry = { max_delivery_count = 3 } }
    topics        = { events = {}, audit = { name = "audit-events" } }
    subscriptions = { worker = { topic_key = "events" }, audit = { topic_key = "audit" } }
    subscription_rules = {
      selected   = { name = "selected-events", subscription_key = "worker", filter_type = "SqlFilter", sql_filter = "priority > 5" }
      correlated = { name = "selected-events", subscription_key = "audit", filter_type = "CorrelationFilter", correlation_filter = { properties = { kind = "audit" } } }
    }
    network_rule_set = { ip_rules = ["203.0.113.8"] }
  }

  assert {
    condition     = length(azurerm_private_endpoint.this) == 2 && azurerm_private_endpoint.this["workload"].name == "example-service-workload" && azurerm_private_endpoint.this["secondary"].name == "custom-endpoint"
    error_message = "Endpoint map keys must preserve independent names and caller overrides."
  }

  assert {
    condition     = alltrue([for endpoint in values(azurerm_private_endpoint.this) : endpoint.private_service_connection[0].private_connection_resource_id == azurerm_servicebus_namespace.this.id])
    error_message = "Every endpoint must target this parent."
  }

  assert {
    condition     = length(azurerm_private_endpoint.this["workload"].private_dns_zone_group) == 1 && length(azurerm_private_endpoint.this["secondary"].private_dns_zone_group) == 0 && azurerm_private_endpoint.this["secondary"].private_service_connection[0].is_manual_connection
    error_message = "DNS grouping and approval mode must follow endpoint intent."
  }

  assert {
    condition     = length(azurerm_role_assignment.this) == 2 && alltrue([for assignment in values(azurerm_role_assignment.this) : assignment.scope == azurerm_servicebus_namespace.this.id])
    error_message = "Role assignments must remain scoped to this parent."
  }

  assert {
    condition     = length(azurerm_servicebus_queue.this) == 2 && azurerm_servicebus_queue.this["retry"].max_delivery_count == 3 && azurerm_servicebus_topic.this["audit"].name == "audit-events"
    error_message = "Queue/topic maps must preserve names and overrides."
  }

  assert {
    condition     = azurerm_servicebus_subscription.this["worker"].topic_id == azurerm_servicebus_topic.this["events"].id && azurerm_servicebus_subscription_rule.this["selected"].subscription_id == azurerm_servicebus_subscription.this["worker"].id && azurerm_servicebus_subscription_rule.this["correlated"].name == "selected-events"
    error_message = "Subscriptions and filters must follow declared parent keys."
  }
}

run "standard_public_opt_in" {
  command = plan

  variables {
    sku                           = "Standard"
    capacity                      = 0
    premium_messaging_partitions  = 0
    public_network_access_enabled = true
    local_auth_enabled            = true
    queues                        = { jobs = {} }
  }

  assert {
    condition     = azurerm_servicebus_namespace.this.public_network_access_enabled && azurerm_servicebus_namespace.this.local_auth_enabled
    error_message = "Caller overrides must be respected."
  }
}

run "reject_standard_private_endpoint" {
  command = plan

  variables {
    sku                          = "Standard"
    capacity                     = 0
    premium_messaging_partitions = 0
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

  expect_failures = [azurerm_servicebus_namespace.this]
}
