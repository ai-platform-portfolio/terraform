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
    subresource_names             = optional(list(string), ["redisEnterprise"])
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

variable "sku_name" {
  description = "Azure Managed Redis SKU, for example Balanced_B0; legacy Enterprise SKUs are unsupported."
  type        = string
}

variable "high_availability_enabled" {
  description = "Enable a replica for high availability; disabled by default for a small deployment."
  type        = bool
  default     = false
}

variable "public_network_access" {
  description = "Public network access: Enabled or Disabled."
  type        = string
  default     = "Disabled"
}

variable "default_database" {
  description = "The single default database; Redis modules are keyed by their Azure module names."
  type = object({
    access_keys_authentication_enabled            = optional(bool, false)
    client_protocol                               = optional(string, "Encrypted")
    clustering_policy                             = optional(string, "OSSCluster")
    eviction_policy                               = optional(string, "VolatileLRU")
    geo_replication_group_name                    = optional(string)
    persistence_append_only_file_backup_frequency = optional(string)
    persistence_redis_database_backup_frequency   = optional(string)
    modules = optional(map(object({
      args = optional(string)
    })), {})
  })
  default = {}
}

variable "access_policy_assignments" {
  description = "Entra object IDs granted data access to the default database; AzureRM 4.81 does not expose custom ACLs."
  type        = map(object({ object_id = string }))
  default     = {}
}
