variable "name" {
  description = "Virtual network name."
  type        = string
}
variable "location" {
  description = "Azure region."
  type        = string
}
variable "resource_group_name" {
  description = "Existing resource group."
  type        = string
}
variable "address_space" {
  description = "VNet address ranges."
  type        = list(string)
}
variable "subnets" {
  description = "Subnets keyed by Azure subnet name."
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
  }))
}
variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
