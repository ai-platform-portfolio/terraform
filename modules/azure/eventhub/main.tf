terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81, < 5.0"
    }
  }
}

resource "azurerm_eventhub_namespace" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  tags                          = var.tags
  sku                           = var.sku
  capacity                      = var.capacity
  auto_inflate_enabled          = var.auto_inflate_enabled
  maximum_throughput_units      = var.maximum_throughput_units
  dedicated_cluster_id          = var.dedicated_cluster_id
  local_authentication_enabled  = var.local_authentication_enabled
  public_network_access_enabled = var.public_network_access_enabled
  minimum_tls_version           = var.minimum_tls_version

  dynamic "identity" {
    for_each = var.identity == null ? [] : [var.identity]

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  dynamic "network_rulesets" {
    for_each = var.network_rulesets == null ? [] : [var.network_rulesets]

    content {
      default_action                 = network_rulesets.value.default_action
      public_network_access_enabled  = var.public_network_access_enabled
      trusted_service_access_enabled = network_rulesets.value.trusted_service_access_enabled

      dynamic "ip_rule" {
        for_each = network_rulesets.value.ip_rules

        content {
          ip_mask = ip_rule.value.ip_mask
          action  = ip_rule.value.action
        }
      }

      dynamic "virtual_network_rule" {
        for_each = network_rulesets.value.virtual_network_rules

        content {
          subnet_id                                       = virtual_network_rule.value.subnet_id
          ignore_missing_virtual_network_service_endpoint = virtual_network_rule.value.ignore_missing_virtual_network_service_endpoint
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = contains(["Basic", "Standard", "Premium"], var.sku) && (var.sku != "Basic" || (length(var.private_endpoints) == 0 && length(var.consumer_groups) == 0 && var.network_rulesets == null))
      error_message = "Private endpoints, network rules and consumer groups require Standard or Premium."
    }

    precondition {
      condition     = !var.auto_inflate_enabled || (var.sku == "Standard" && var.maximum_throughput_units != null)
      error_message = "Auto inflate requires Standard and maximum_throughput_units."
    }

    precondition {
      condition = alltrue([for hub in values(var.eventhubs) : hub.capture_description == null ? true : !hub.capture_description.enabled ? true : (
        hub.capture_description.destination.storage_authentication_type == "SystemAssigned" ? (
          var.identity == null ? false : contains(split(", ", var.identity.type), "SystemAssigned")
          ) : hub.capture_description.destination.storage_authentication_type == "UserAssigned" ? (
          var.identity == null ? false : try(contains(var.identity.identity_ids, hub.capture_description.destination.storage_authentication_id), false)
        ) : true
      )])
      error_message = "Capture must use an enabled namespace identity matching its SystemAssigned or UserAssigned destination settings."
    }

    precondition {
      condition     = alltrue([for group in values(var.consumer_groups) : contains(keys(var.eventhubs), group.eventhub_key)])
      error_message = "Consumer groups must reference declared eventhubs map keys."
    }
  }
}

resource "azurerm_private_endpoint" "this" {
  for_each = var.private_endpoints

  name                          = coalesce(each.value.name, "${var.name}-${each.key}")
  resource_group_name           = coalesce(each.value.resource_group_name, var.resource_group_name)
  location                      = coalesce(each.value.location, var.location)
  subnet_id                     = each.value.subnet_id
  custom_network_interface_name = each.value.custom_network_interface_name
  tags                          = merge(var.tags, each.value.tags)

  private_service_connection {
    name                           = coalesce(each.value.connection_name, each.value.name, "${var.name}-${each.key}")
    private_connection_resource_id = azurerm_eventhub_namespace.this.id
    subresource_names              = each.value.subresource_names
    is_manual_connection           = each.value.is_manual_connection
    request_message                = each.value.request_message
  }

  dynamic "private_dns_zone_group" {
    for_each = length(each.value.private_dns_zone_ids) == 0 ? [] : [each.value]

    content {
      name                 = private_dns_zone_group.value.private_dns_zone_group_name
      private_dns_zone_ids = private_dns_zone_group.value.private_dns_zone_ids
    }
  }

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.key
      private_ip_address = ip_configuration.value.private_ip_address
      subresource_name   = ip_configuration.value.subresource_name
      member_name        = ip_configuration.value.member_name
    }
  }
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                            = azurerm_eventhub_namespace.this.id
  principal_id                     = each.value.principal_id
  role_definition_name             = each.value.role_definition_name
  principal_type                   = each.value.principal_type
  skip_service_principal_aad_check = each.value.skip_service_principal_aad_check
  condition                        = each.value.condition
  condition_version                = each.value.condition_version
  description                      = each.value.description
}

resource "azurerm_eventhub" "this" {
  for_each = var.eventhubs

  name            = coalesce(each.value.name, each.key)
  namespace_id    = azurerm_eventhub_namespace.this.id
  partition_count = each.value.partition_count
  status          = each.value.status

  retention_description {
    cleanup_policy                    = each.value.retention_description.cleanup_policy
    retention_time_in_hours           = each.value.retention_description.retention_time_in_hours
    tombstone_retention_time_in_hours = each.value.retention_description.tombstone_retention_time_in_hours
  }

  dynamic "capture_description" {
    for_each = each.value.capture_description == null ? [] : [each.value.capture_description]

    content {
      enabled             = capture_description.value.enabled
      encoding            = capture_description.value.encoding
      interval_in_seconds = capture_description.value.interval_in_seconds
      size_limit_in_bytes = capture_description.value.size_limit_in_bytes
      skip_empty_archives = capture_description.value.skip_empty_archives

      destination {
        name                        = capture_description.value.destination.name
        archive_name_format         = capture_description.value.destination.archive_name_format
        blob_container_name         = capture_description.value.destination.blob_container_name
        storage_account_id          = capture_description.value.destination.storage_account_id
        storage_authentication_type = capture_description.value.destination.storage_authentication_type
        storage_authentication_id   = capture_description.value.destination.storage_authentication_id
      }
    }
  }
}

resource "azurerm_eventhub_consumer_group" "this" {
  for_each = var.consumer_groups

  name                = coalesce(each.value.name, each.key)
  namespace_name      = azurerm_eventhub_namespace.this.name
  resource_group_name = var.resource_group_name
  eventhub_name       = azurerm_eventhub.this[each.value.eventhub_key].name
  user_metadata       = each.value.user_metadata
}
