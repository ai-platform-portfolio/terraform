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
  description = "Namespace tier; private endpoints and consumer groups require Standard or Premium."
  type        = string
  default     = "Standard"
}

variable "capacity" {
  description = "Namespace throughput or processing units."
  type        = number
  default     = 1
}

variable "auto_inflate_enabled" {
  description = "Enable automatic throughput inflation on Standard."
  type        = bool
  default     = false
}

variable "maximum_throughput_units" {
  description = "Maximum throughput when auto inflate is enabled."
  type        = number
  default     = null
}

variable "dedicated_cluster_id" {
  description = "Optional existing dedicated Event Hubs cluster ID."
  type        = string
  default     = null
}

variable "local_authentication_enabled" {
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

variable "network_rulesets" {
  description = "Optional namespace firewall; public-access setting follows the namespace."
  type = object({
    default_action                 = optional(string, "Deny")
    trusted_service_access_enabled = optional(bool, false)
    ip_rules = optional(map(object({
      ip_mask = string
      action  = optional(string, "Allow")
    })), {})
    virtual_network_rules = optional(map(object({
      subnet_id                                       = string
      ignore_missing_virtual_network_service_endpoint = optional(bool, false)
    })), {})
  })
  default = null
}

variable "eventhubs" {
  description = "Event hubs keyed by purpose; capture storage and its identity grants must already exist."
  type = map(object({
    name            = optional(string)
    partition_count = optional(number, 2)
    status          = optional(string, "Active")
    retention_description = optional(object({
      cleanup_policy                    = optional(string, "Delete")
      retention_time_in_hours           = optional(number, 24)
      tombstone_retention_time_in_hours = optional(number)
    }), {})
    capture_description = optional(object({
      enabled             = optional(bool, true)
      encoding            = optional(string, "Avro")
      interval_in_seconds = optional(number, 300)
      size_limit_in_bytes = optional(number, 314572800)
      skip_empty_archives = optional(bool, true)
      destination = object({
        name                        = optional(string, "EventHubArchive.AzureBlockBlob")
        archive_name_format         = optional(string, "{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}")
        blob_container_name         = string
        storage_account_id          = string
        storage_authentication_type = optional(string, "SystemAssigned")
        storage_authentication_id   = optional(string)
      })
    }))
  }))
  default = {}
}

variable "consumer_groups" {
  description = "Consumer groups referencing an eventhubs map key."
  type = map(object({
    name          = optional(string)
    eventhub_key  = string
    user_metadata = optional(string)
  }))
  default = {}
}
