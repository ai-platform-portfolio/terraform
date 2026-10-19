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
    address_prefixes            = list(string)
    service_endpoints           = optional(list(string), [])
    network_security_group_name = optional(string)
  }))
}
variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "network_security_group_name_prefix" {
  description = "Default NSG name prefix; a subnet's network_security_group_name overrides the generated name."
  type        = string
  default     = "nsg-"
}

variable "route_tables" {
  description = "Optional route tables keyed by logical name. Azure name defaults to the key; routes are keyed by route name. Empty maps create no route tables or routes."
  type = map(object({
    name                          = optional(string)
    bgp_route_propagation_enabled = optional(bool, true)
    routes = optional(map(object({
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = optional(string)
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for table in values(var.route_tables) : [
        for route in values(table.routes) :
        contains(["VirtualNetworkGateway", "VnetLocal", "Internet", "VirtualAppliance", "None"], route.next_hop_type)
      ]
    ]))
    error_message = "Each route must use an Azure-supported next_hop_type."
  }

  validation {
    condition = alltrue(flatten([
      for table in values(var.route_tables) : [
        for route in values(table.routes) :
        route.next_hop_type == "VirtualAppliance" ? can(cidrnetmask("${route.next_hop_in_ip_address}/32")) : route.next_hop_in_ip_address == null
      ]
    ]))
    error_message = "VirtualAppliance routes require a valid IPv4 next_hop_in_ip_address; other next hop types must omit it."
  }
}

variable "route_table_subnet_associations" {
  description = "Map of subnet key to route table key. Both keys must exist in subnets and route_tables. Each subnet can use one route table; a table can be shared."
  type        = map(string)
  default     = {}
}
