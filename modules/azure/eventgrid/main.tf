terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81, < 5.0"
    }
  }
}

resource "azurerm_eventgrid_domain" "this" {
  name                                      = var.name
  resource_group_name                       = var.resource_group_name
  location                                  = var.location
  tags                                      = var.tags
  input_schema                              = var.input_schema
  public_network_access_enabled             = var.public_network_access_enabled
  local_auth_enabled                        = var.local_auth_enabled
  auto_create_topic_with_first_subscription = var.auto_create_topic_with_first_subscription
  auto_delete_topic_with_last_subscription  = var.auto_delete_topic_with_last_subscription

  dynamic "identity" {
    for_each = var.identity == null ? [] : [var.identity]

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  dynamic "inbound_ip_rule" {
    for_each = var.inbound_ip_rules

    content {
      ip_mask = inbound_ip_rule.value.ip_mask
      action  = inbound_ip_rule.value.action
    }
  }

  lifecycle {
    precondition {
      condition     = alltrue([for subscription in values(var.event_subscriptions) : subscription.topic_key == null ? true : contains(keys(var.topics), subscription.topic_key)])
      error_message = "Event subscriptions must reference a declared topic_key or omit it for domain scope."
    }

    precondition {
      condition = alltrue([for subscription in values(var.event_subscriptions) : length([for destination in [
        subscription.eventhub_endpoint_id != null,
        subscription.hybrid_connection_endpoint_id != null,
        subscription.service_bus_queue_endpoint_id != null,
        subscription.service_bus_topic_endpoint_id != null,
        subscription.azure_function_endpoint != null,
        subscription.storage_queue_endpoint != null,
        subscription.webhook_endpoint != null
      ] : destination if destination]) == 1])
      error_message = "Each event subscription requires exactly one destination."
    }

    precondition {
      condition     = alltrue([for subscription in values(var.event_subscriptions) : subscription.dead_letter_identity == null || subscription.storage_blob_dead_letter_destination != null])
      error_message = "A dead-letter identity requires a storage blob dead-letter destination."
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
    private_connection_resource_id = azurerm_eventgrid_domain.this.id
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

  scope                            = azurerm_eventgrid_domain.this.id
  principal_id                     = each.value.principal_id
  role_definition_name             = each.value.role_definition_name
  principal_type                   = each.value.principal_type
  skip_service_principal_aad_check = each.value.skip_service_principal_aad_check
  condition                        = each.value.condition
  condition_version                = each.value.condition_version
  description                      = each.value.description
}

resource "azurerm_eventgrid_domain_topic" "this" {
  for_each = var.topics

  name                = coalesce(each.value.name, each.key)
  domain_name         = azurerm_eventgrid_domain.this.name
  resource_group_name = var.resource_group_name
}

resource "azurerm_eventgrid_event_subscription" "this" {
  for_each = var.event_subscriptions

  name                                 = coalesce(each.value.name, each.key)
  scope                                = each.value.topic_key == null ? azurerm_eventgrid_domain.this.id : azurerm_eventgrid_domain_topic.this[each.value.topic_key].id
  expiration_time_utc                  = each.value.expiration_time_utc
  event_delivery_schema                = each.value.event_delivery_schema
  eventhub_endpoint_id                 = each.value.eventhub_endpoint_id
  hybrid_connection_endpoint_id        = each.value.hybrid_connection_endpoint_id
  service_bus_queue_endpoint_id        = each.value.service_bus_queue_endpoint_id
  service_bus_topic_endpoint_id        = each.value.service_bus_topic_endpoint_id
  included_event_types                 = each.value.included_event_types
  labels                               = each.value.labels
  advanced_filtering_on_arrays_enabled = each.value.advanced_filtering_on_arrays_enabled

  dynamic "azure_function_endpoint" {
    for_each = each.value.azure_function_endpoint == null ? [] : [each.value.azure_function_endpoint]

    content {
      function_id                       = azure_function_endpoint.value.function_id
      max_events_per_batch              = azure_function_endpoint.value.max_events_per_batch
      preferred_batch_size_in_kilobytes = azure_function_endpoint.value.preferred_batch_size_in_kilobytes
    }
  }

  dynamic "storage_queue_endpoint" {
    for_each = each.value.storage_queue_endpoint == null ? [] : [each.value.storage_queue_endpoint]

    content {
      storage_account_id                    = storage_queue_endpoint.value.storage_account_id
      queue_name                            = storage_queue_endpoint.value.queue_name
      queue_message_time_to_live_in_seconds = storage_queue_endpoint.value.queue_message_time_to_live_in_seconds
    }
  }

  dynamic "webhook_endpoint" {
    for_each = each.value.webhook_endpoint == null ? [] : [each.value.webhook_endpoint]

    content {
      url                               = webhook_endpoint.value.url
      max_events_per_batch              = webhook_endpoint.value.max_events_per_batch
      preferred_batch_size_in_kilobytes = webhook_endpoint.value.preferred_batch_size_in_kilobytes
      active_directory_tenant_id        = webhook_endpoint.value.active_directory_tenant_id
      active_directory_app_id_or_uri    = webhook_endpoint.value.active_directory_app_id_or_uri
    }
  }

  dynamic "subject_filter" {
    for_each = each.value.subject_filter == null ? [] : [each.value.subject_filter]

    content {
      subject_begins_with = subject_filter.value.subject_begins_with
      subject_ends_with   = subject_filter.value.subject_ends_with
      case_sensitive      = subject_filter.value.case_sensitive
    }
  }

  dynamic "delivery_identity" {
    for_each = each.value.delivery_identity == null ? [] : [each.value.delivery_identity]

    content {
      type                   = delivery_identity.value.type
      user_assigned_identity = delivery_identity.value.user_assigned_identity
    }
  }

  dynamic "dead_letter_identity" {
    for_each = each.value.dead_letter_identity == null ? [] : [each.value.dead_letter_identity]

    content {
      type                   = dead_letter_identity.value.type
      user_assigned_identity = dead_letter_identity.value.user_assigned_identity
    }
  }

  dynamic "storage_blob_dead_letter_destination" {
    for_each = each.value.storage_blob_dead_letter_destination == null ? [] : [each.value.storage_blob_dead_letter_destination]

    content {
      storage_account_id          = storage_blob_dead_letter_destination.value.storage_account_id
      storage_blob_container_name = storage_blob_dead_letter_destination.value.storage_blob_container_name
    }
  }

  retry_policy {
    max_delivery_attempts = each.value.retry_policy.max_delivery_attempts
    event_time_to_live    = each.value.retry_policy.event_time_to_live
  }

  dynamic "advanced_filter" {
    for_each = each.value.advanced_filter == null ? [] : [each.value.advanced_filter]

    content {
      dynamic "bool_equals" {
        for_each = advanced_filter.value.bool_equals

        content {
          key   = bool_equals.value.key
          value = bool_equals.value.value
        }
      }

      dynamic "number_greater_than" {
        for_each = advanced_filter.value.number_greater_than

        content {
          key   = number_greater_than.value.key
          value = number_greater_than.value.value
        }
      }

      dynamic "number_greater_than_or_equals" {
        for_each = advanced_filter.value.number_greater_than_or_equals

        content {
          key   = number_greater_than_or_equals.value.key
          value = number_greater_than_or_equals.value.value
        }
      }

      dynamic "number_less_than" {
        for_each = advanced_filter.value.number_less_than

        content {
          key   = number_less_than.value.key
          value = number_less_than.value.value
        }
      }

      dynamic "number_less_than_or_equals" {
        for_each = advanced_filter.value.number_less_than_or_equals

        content {
          key   = number_less_than_or_equals.value.key
          value = number_less_than_or_equals.value.value
        }
      }

      dynamic "number_in" {
        for_each = advanced_filter.value.number_in

        content {
          key    = number_in.value.key
          values = number_in.value.values
        }
      }

      dynamic "number_not_in" {
        for_each = advanced_filter.value.number_not_in

        content {
          key    = number_not_in.value.key
          values = number_not_in.value.values
        }
      }

      dynamic "number_in_range" {
        for_each = advanced_filter.value.number_in_range

        content {
          key    = number_in_range.value.key
          values = number_in_range.value.values
        }
      }

      dynamic "number_not_in_range" {
        for_each = advanced_filter.value.number_not_in_range

        content {
          key    = number_not_in_range.value.key
          values = number_not_in_range.value.values
        }
      }

      dynamic "string_begins_with" {
        for_each = advanced_filter.value.string_begins_with

        content {
          key    = string_begins_with.value.key
          values = string_begins_with.value.values
        }
      }

      dynamic "string_not_begins_with" {
        for_each = advanced_filter.value.string_not_begins_with

        content {
          key    = string_not_begins_with.value.key
          values = string_not_begins_with.value.values
        }
      }

      dynamic "string_ends_with" {
        for_each = advanced_filter.value.string_ends_with

        content {
          key    = string_ends_with.value.key
          values = string_ends_with.value.values
        }
      }

      dynamic "string_not_ends_with" {
        for_each = advanced_filter.value.string_not_ends_with

        content {
          key    = string_not_ends_with.value.key
          values = string_not_ends_with.value.values
        }
      }

      dynamic "string_contains" {
        for_each = advanced_filter.value.string_contains

        content {
          key    = string_contains.value.key
          values = string_contains.value.values
        }
      }

      dynamic "string_not_contains" {
        for_each = advanced_filter.value.string_not_contains

        content {
          key    = string_not_contains.value.key
          values = string_not_contains.value.values
        }
      }

      dynamic "string_in" {
        for_each = advanced_filter.value.string_in

        content {
          key    = string_in.value.key
          values = string_in.value.values
        }
      }

      dynamic "string_not_in" {
        for_each = advanced_filter.value.string_not_in

        content {
          key    = string_not_in.value.key
          values = string_not_in.value.values
        }
      }

      dynamic "is_not_null" {
        for_each = advanced_filter.value.is_not_null

        content {
          key = is_not_null.value.key
        }
      }

      dynamic "is_null_or_undefined" {
        for_each = advanced_filter.value.is_null_or_undefined

        content {
          key = is_null_or_undefined.value.key
        }
      }
    }
  }
}
