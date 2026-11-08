variable "name" {
  description = "Parent resource name."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group for the service."
  type        = string
}

variable "location" {
  description = "Azure region for the service."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "identity" {
  description = "Optional managed identity; caller owns user-assigned identity resources."
  type = object({
    type         = string
    identity_ids = optional(list(string), [])
  })
  default = null
}

variable "private_endpoints" {
  description = "Private endpoints keyed by purpose; caller owns subnets, DNS zones and VNet links."
  type = map(object({
    name                          = optional(string)
    location                      = optional(string)
    resource_group_name           = optional(string)
    subnet_id                     = string
    custom_network_interface_name = optional(string)
    connection_name               = optional(string)
    is_manual_connection          = optional(bool, false)
    request_message               = optional(string)
    subresource_names             = optional(list(string), ["namespace"])
    private_dns_zone_ids          = optional(list(string), [])
    private_dns_zone_group_name   = optional(string, "default")
    ip_configurations = optional(map(object({
      private_ip_address = string
      subresource_name   = string
      member_name        = string
    })), {})
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "role_assignments" {
  description = "Azure role assignments scoped to this parent; no SAS authorization rules are created."
  type = map(object({
    principal_id                     = string
    role_definition_name             = string
    principal_type                   = optional(string)
    skip_service_principal_aad_check = optional(bool, false)
    condition                        = optional(string)
    condition_version                = optional(string)
    description                      = optional(string)
  }))
  default = {}
}

variable "sku" {
  description = "Namespace tier; private endpoints require Premium."
  type        = string
  default     = "Premium"
}

variable "capacity" {
  description = "Messaging units for Premium; set 0 for Basic/Standard."
  type        = number
  default     = 1
}

variable "premium_messaging_partitions" {
  description = "Premium partition count (1, 2, 4); set 0 for Basic/Standard."
  type        = number
  default     = 1
}

variable "local_auth_enabled" {
  description = "Enable SAS authentication; Entra authentication is preferred."
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Allow public network access."
  type        = bool
  default     = false
}

variable "minimum_tls_version" {
  description = "Minimum TLS version; AzureRM 4.81 supports up to 1.2 and Azure requires TLS 1.2 or newer."
  type        = string
  default     = "1.2"

  validation {
    condition     = var.minimum_tls_version == "1.2"
    error_message = "Use TLS 1.2; older protocols are retired and AzureRM 4.81 does not expose TLS 1.3."
  }
}

variable "network_rule_set" {
  description = "Optional Premium namespace firewall; public-access setting follows the namespace."
  type = object({
    default_action           = optional(string, "Deny")
    trusted_services_allowed = optional(bool, false)
    ip_rules                 = optional(list(string), [])
    network_rules = optional(map(object({
      subnet_id                            = string
      ignore_missing_vnet_service_endpoint = optional(bool, false)
    })), {})
  })
  default = null
}

variable "queues" {
  description = "Named queues; names default to map keys. Subscriptions reference topics by topic_key."
  type = map(object({
    name                                    = optional(string)
    lock_duration                           = optional(string, "PT1M")
    max_message_size_in_kilobytes           = optional(number)
    max_size_in_megabytes                   = optional(number)
    requires_duplicate_detection            = optional(bool, false)
    requires_session                        = optional(bool, false)
    default_message_ttl                     = optional(string)
    dead_lettering_on_message_expiration    = optional(bool, false)
    duplicate_detection_history_time_window = optional(string, "PT10M")
    max_delivery_count                      = optional(number, 10)
    status                                  = optional(string, "Active")
    batched_operations_enabled              = optional(bool, true)
    auto_delete_on_idle                     = optional(string)
    partitioning_enabled                    = optional(bool, false)
    express_enabled                         = optional(bool, false)
    forward_to                              = optional(string)
    forward_dead_lettered_messages_to       = optional(string)
  }))
  default = {}
}

variable "topics" {
  description = "Named topics; names default to map keys. Subscriptions reference topics by topic_key."
  type = map(object({
    name                                    = optional(string)
    max_message_size_in_kilobytes           = optional(number)
    max_size_in_megabytes                   = optional(number)
    requires_duplicate_detection            = optional(bool, false)
    default_message_ttl                     = optional(string)
    duplicate_detection_history_time_window = optional(string, "PT10M")
    status                                  = optional(string, "Active")
    batched_operations_enabled              = optional(bool, true)
    auto_delete_on_idle                     = optional(string)
    partitioning_enabled                    = optional(bool, false)
    express_enabled                         = optional(bool, false)
    support_ordering                        = optional(bool, false)
  }))
  default = {}
}

variable "subscriptions" {
  description = "Named subscriptions; names default to map keys. Subscriptions reference topics by topic_key."
  type = map(object({
    name                                      = optional(string)
    topic_key                                 = string
    lock_duration                             = optional(string, "PT1M")
    requires_session                          = optional(bool, false)
    default_message_ttl                       = optional(string)
    dead_lettering_on_message_expiration      = optional(bool, false)
    max_delivery_count                        = optional(number, 10)
    status                                    = optional(string, "Active")
    batched_operations_enabled                = optional(bool, true)
    auto_delete_on_idle                       = optional(string)
    forward_to                                = optional(string)
    forward_dead_lettered_messages_to         = optional(string)
    dead_lettering_on_filter_evaluation_error = optional(bool, true)
  }))
  default = {}
}

variable "subscription_rules" {
  description = "SQL or correlation rules referencing subscriptions by map key; caller provider must remove the Azure catch-all rule for filtering."
  type = map(object({
    name             = optional(string)
    subscription_key = string
    filter_type      = string
    sql_filter       = optional(string)
    action           = optional(string)
    correlation_filter = optional(object({
      content_type        = optional(string)
      correlation_id      = optional(string)
      label               = optional(string)
      message_id          = optional(string)
      reply_to            = optional(string)
      reply_to_session_id = optional(string)
      session_id          = optional(string)
      to                  = optional(string)
      properties          = optional(map(string), {})
    }))
  }))
  default = {}
}
