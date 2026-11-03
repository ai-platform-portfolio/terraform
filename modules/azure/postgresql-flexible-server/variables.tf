variable "name" {
  description = "Globally unique Flexible Server name."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group for the server and private endpoint."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "zone" {
  description = "Availability zone for the server; set explicitly to preserve a stable plan."
  type        = string
}

variable "tenant_id" {
  description = "Tenant ID from the authenticated caller context."
  type        = string
  sensitive   = true
}

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
}

variable "sku_name" {
  description = "Flexible Server compute SKU."
  type        = string
}

variable "storage_mb" {
  description = "Provisioned storage in MiB."
  type        = number
}

variable "auto_grow_enabled" {
  description = "Allow Azure to increase storage when needed."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Point-in-time backup retention, from 7 to 35 days."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 7 and 35."
  }
}

variable "private_endpoint_subnet_id" {
  description = "Subnet for the server private endpoint."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for privatelink.postgres.database.azure.com."
  type        = string
}

variable "entra_administrators" {
  description = "Microsoft Entra principals authorized as server administrators, keyed by purpose."
  type = map(object({
    object_id      = string
    principal_name = string
    principal_type = string
  }))

  validation {
    condition     = length(var.entra_administrators) > 0 && alltrue([for admin in values(var.entra_administrators) : contains(["Group", "ServicePrincipal", "User"], admin.principal_type)])
    error_message = "Provide at least one Entra administrator of type Group, ServicePrincipal or User."
  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
