terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81, < 5.0"
    }
  }
}

resource "azurerm_servicebus_namespace" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  tags                          = var.tags
  sku                           = var.sku
  capacity                      = var.capacity
  premium_messaging_partitions  = var.premium_messaging_partitions
  local_auth_enabled            = var.local_auth_enabled
  public_network_access_enabled = var.public_network_access_enabled
  minimum_tls_version           = var.minimum_tls_version

  dynamic "identity" {
    for_each = var.identity == null ? [] : [var.identity]

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  dynamic "network_rule_set" {
    for_each = var.network_rule_set == null ? [] : [var.network_rule_set]

    content {
      default_action                = network_rule_set.value.default_action
      public_network_access_enabled = var.public_network_access_enabled
      trusted_services_allowed      = network_rule_set.value.trusted_services_allowed
      ip_rules                      = network_rule_set.value.ip_rules

      dynamic "network_rules" {
        for_each = network_rule_set.value.network_rules

        content {
          subnet_id                            = network_rules.value.subnet_id
          ignore_missing_vnet_service_endpoint = network_rules.value.ignore_missing_vnet_service_endpoint
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition = contains(["Basic", "Standard", "Premium"], var.sku) && (
        var.sku == "Premium" ? contains([1, 2, 4, 8, 16], var.capacity) && contains([1, 2, 4], var.premium_messaging_partitions) : var.capacity == 0 && var.premium_messaging_partitions == 0
      )
      error_message = "Premium requires capacity 1/2/4/8/16 and partitions 1/2/4; Basic/Standard require both set to 0."
    }

    precondition {
      condition     = var.sku == "Premium" || (length(var.private_endpoints) == 0 && var.network_rule_set == null)
      error_message = "Service Bus private endpoints and network rules require Premium."
    }

    precondition {
      condition     = var.sku != "Basic" || length(var.topics) == 0
      error_message = "Service Bus topics require Standard or Premium."
    }

    precondition {
      condition     = alltrue([for subscription in values(var.subscriptions) : contains(keys(var.topics), subscription.topic_key)]) && alltrue([for rule in values(var.subscription_rules) : contains(keys(var.subscriptions), rule.subscription_key)])
      error_message = "Subscriptions and rules must reference declared topic and subscription map keys."
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
    private_connection_resource_id = azurerm_servicebus_namespace.this.id
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

  scope                            = azurerm_servicebus_namespace.this.id
  principal_id                     = each.value.principal_id
  role_definition_name             = each.value.role_definition_name
  principal_type                   = each.value.principal_type
  skip_service_principal_aad_check = each.value.skip_service_principal_aad_check
  condition                        = each.value.condition
  condition_version                = each.value.condition_version
  description                      = each.value.description
}

resource "azurerm_servicebus_queue" "this" {
  for_each = var.queues

  name                                    = coalesce(each.value.name, each.key)
  namespace_id                            = azurerm_servicebus_namespace.this.id
  lock_duration                           = each.value.lock_duration
  max_message_size_in_kilobytes           = each.value.max_message_size_in_kilobytes
  max_size_in_megabytes                   = each.value.max_size_in_megabytes
  requires_duplicate_detection            = each.value.requires_duplicate_detection
  requires_session                        = each.value.requires_session
  default_message_ttl                     = each.value.default_message_ttl
  dead_lettering_on_message_expiration    = each.value.dead_lettering_on_message_expiration
  duplicate_detection_history_time_window = each.value.duplicate_detection_history_time_window
  max_delivery_count                      = each.value.max_delivery_count
  status                                  = each.value.status
  batched_operations_enabled              = each.value.batched_operations_enabled
  auto_delete_on_idle                     = each.value.auto_delete_on_idle
  partitioning_enabled                    = each.value.partitioning_enabled
  express_enabled                         = each.value.express_enabled
  forward_to                              = each.value.forward_to
  forward_dead_lettered_messages_to       = each.value.forward_dead_lettered_messages_to
}

resource "azurerm_servicebus_topic" "this" {
  for_each = var.topics

  name                                    = coalesce(each.value.name, each.key)
  namespace_id                            = azurerm_servicebus_namespace.this.id
  max_message_size_in_kilobytes           = each.value.max_message_size_in_kilobytes
  max_size_in_megabytes                   = each.value.max_size_in_megabytes
  requires_duplicate_detection            = each.value.requires_duplicate_detection
  default_message_ttl                     = each.value.default_message_ttl
  duplicate_detection_history_time_window = each.value.duplicate_detection_history_time_window
  status                                  = each.value.status
  batched_operations_enabled              = each.value.batched_operations_enabled
  auto_delete_on_idle                     = each.value.auto_delete_on_idle
  partitioning_enabled                    = each.value.partitioning_enabled
  express_enabled                         = each.value.express_enabled
  support_ordering                        = each.value.support_ordering
}

resource "azurerm_servicebus_subscription" "this" {
  for_each = var.subscriptions

  name                                      = coalesce(each.value.name, each.key)
  topic_id                                  = azurerm_servicebus_topic.this[each.value.topic_key].id
  lock_duration                             = each.value.lock_duration
  requires_session                          = each.value.requires_session
  default_message_ttl                       = each.value.default_message_ttl
  dead_lettering_on_message_expiration      = each.value.dead_lettering_on_message_expiration
  max_delivery_count                        = each.value.max_delivery_count
  status                                    = each.value.status
  batched_operations_enabled                = each.value.batched_operations_enabled
  auto_delete_on_idle                       = each.value.auto_delete_on_idle
  forward_to                                = each.value.forward_to
  forward_dead_lettered_messages_to         = each.value.forward_dead_lettered_messages_to
  dead_lettering_on_filter_evaluation_error = each.value.dead_lettering_on_filter_evaluation_error
}

resource "azurerm_servicebus_subscription_rule" "this" {
  for_each = var.subscription_rules

  name            = coalesce(each.value.name, each.key)
  subscription_id = azurerm_servicebus_subscription.this[each.value.subscription_key].id
  filter_type     = each.value.filter_type
  sql_filter      = each.value.sql_filter
  action          = each.value.action

  dynamic "correlation_filter" {
    for_each = each.value.correlation_filter == null ? [] : [each.value.correlation_filter]

    content {
      content_type        = correlation_filter.value.content_type
      correlation_id      = correlation_filter.value.correlation_id
      label               = correlation_filter.value.label
      message_id          = correlation_filter.value.message_id
      reply_to            = correlation_filter.value.reply_to
      reply_to_session_id = correlation_filter.value.reply_to_session_id
      session_id          = correlation_filter.value.session_id
      to                  = correlation_filter.value.to
      properties          = correlation_filter.value.properties
    }
  }
}
