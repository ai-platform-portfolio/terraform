variable "name" {
  description = "Globally unique API Management service name."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group shared with the environment network."
  type        = string
}

variable "location" {
  description = "APIM region; must match its outbound integration VNet."
  type        = string
}

variable "publisher_name" {
  description = "Publisher name supplied externally by the caller."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.publisher_name)) > 0
    error_message = "Publisher name cannot be empty."
  }
}

variable "publisher_email" {
  description = "Publisher contact email supplied externally by the caller."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.publisher_email))
    error_message = "Provide a valid publisher contact email."
  }
}

variable "sku_name" {
  description = "Standard v2 SKU and capacity, for example StandardV2_1."
  type        = string

  validation {
    condition     = can(regex("^StandardV2_([1-9]|10)$", var.sku_name))
    error_message = "This module supports StandardV2_1 through StandardV2_10."
  }
}

variable "integration_subnet_id" {
  description = "Dedicated /27 or larger subnet delegated to Microsoft.Web/serverFarms."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Separate undelegated subnet for the inbound private endpoint."
  type        = string

  validation {
    condition     = var.private_endpoint_subnet_id != var.integration_subnet_id
    error_message = "Integration and private endpoint subnets must be different."
  }
}

variable "private_dns_zone_id" {
  description = "Existing privatelink.azure-api.net DNS zone linked to client VNets."
  type        = string
}

variable "tags" {
  description = "Resource tags supplied by the environment."
  type        = map(string)
  default     = {}
}

variable "managed_identity_id" {
  description = "Shared user-assigned identity owned by the environment, alongside its resource group."
  type        = string
}

variable "timeouts" {
  description = "APIM provisioning and private-access update timeouts; callers can override each operation."
  type = object({
    create = optional(string, "3h")
    update = optional(string, "3h")
    delete = optional(string, "3h")
  })
  default = {}
}
