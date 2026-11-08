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
    subresource_names             = optional(list(string), ["domain"])
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

variable "input_schema" {
  description = "Incoming event schema."
  type        = string
  default     = "EventGridSchema"
}

variable "public_network_access_enabled" {
  description = "Allow public ingress."
  type        = bool
  default     = false
}

variable "local_auth_enabled" {
  description = "Enable shared-key authentication."
  type        = bool
  default     = false
}

variable "auto_create_topic_with_first_subscription" {
  description = "Let Azure create topics implicitly; false keeps explicit Terraform ownership."
  type        = bool
  default     = false
}

variable "auto_delete_topic_with_last_subscription" {
  description = "Let Azure delete topics implicitly; false preserves independently managed topics."
  type        = bool
  default     = false
}

variable "inbound_ip_rules" {
  description = "Optional public-ingress allow rules."
  type = map(object({
    ip_mask = string
    action  = optional(string, "Allow")
  }))
  default = {}
}

variable "topics" {
  description = "Domain topics keyed by purpose; names default to map keys."
  type        = map(object({ name = optional(string) }))
  default     = {}
}

variable "event_subscriptions" {
  description = "Event subscriptions on the domain or a declared topic_key; specify exactly one destination."
  type = map(object({
    name                          = optional(string)
    topic_key                     = optional(string)
    expiration_time_utc           = optional(string)
    event_delivery_schema         = optional(string, "EventGridSchema")
    eventhub_endpoint_id          = optional(string)
    hybrid_connection_endpoint_id = optional(string)
    service_bus_queue_endpoint_id = optional(string)
    service_bus_topic_endpoint_id = optional(string)
    azure_function_endpoint = optional(object({
      function_id                       = string
      max_events_per_batch              = optional(number)
      preferred_batch_size_in_kilobytes = optional(number)
    }))
    storage_queue_endpoint = optional(object({
      storage_account_id                    = string
      queue_name                            = string
      queue_message_time_to_live_in_seconds = optional(number)
    }))
    webhook_endpoint = optional(object({
      url                               = string
      max_events_per_batch              = optional(number)
      preferred_batch_size_in_kilobytes = optional(number)
      active_directory_tenant_id        = optional(string)
      active_directory_app_id_or_uri    = optional(string)
    }))
    included_event_types = optional(list(string))
    labels               = optional(list(string))
    subject_filter = optional(object({
      subject_begins_with = optional(string)
      subject_ends_with   = optional(string)
      case_sensitive      = optional(bool, false)
    }))
    advanced_filtering_on_arrays_enabled = optional(bool, false)
    advanced_filter = optional(object({
      bool_equals                   = optional(list(object({ key = string, value = bool })), [])
      number_greater_than           = optional(list(object({ key = string, value = number })), [])
      number_greater_than_or_equals = optional(list(object({ key = string, value = number })), [])
      number_less_than              = optional(list(object({ key = string, value = number })), [])
      number_less_than_or_equals    = optional(list(object({ key = string, value = number })), [])
      number_in                     = optional(list(object({ key = string, values = list(number) })), [])
      number_not_in                 = optional(list(object({ key = string, values = list(number) })), [])
      number_in_range               = optional(list(object({ key = string, values = list(list(number)) })), [])
      number_not_in_range           = optional(list(object({ key = string, values = list(list(number)) })), [])
      string_begins_with            = optional(list(object({ key = string, values = list(string) })), [])
      string_not_begins_with        = optional(list(object({ key = string, values = list(string) })), [])
      string_ends_with              = optional(list(object({ key = string, values = list(string) })), [])
      string_not_ends_with          = optional(list(object({ key = string, values = list(string) })), [])
      string_contains               = optional(list(object({ key = string, values = list(string) })), [])
      string_not_contains           = optional(list(object({ key = string, values = list(string) })), [])
      string_in                     = optional(list(object({ key = string, values = list(string) })), [])
      string_not_in                 = optional(list(object({ key = string, values = list(string) })), [])
      is_not_null                   = optional(list(object({ key = string })), [])
      is_null_or_undefined          = optional(list(object({ key = string })), [])
    }))
    delivery_identity = optional(object({
      type                   = string
      user_assigned_identity = optional(string)
    }))
    dead_letter_identity = optional(object({
      type                   = string
      user_assigned_identity = optional(string)
    }))
    storage_blob_dead_letter_destination = optional(object({
      storage_account_id          = string
      storage_blob_container_name = string
    }))
    retry_policy = optional(object({
      max_delivery_attempts = optional(number, 30)
      event_time_to_live    = optional(number, 1440)
    }), {})
  }))
  default = {}
}
