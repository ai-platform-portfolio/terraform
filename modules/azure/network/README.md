# network

Creates a virtual network, named subnets, an NSG per subnet, and optional route tables, routes, subnet associations and links to caller-owned private DNS zones. NSGs use Azure default rules. The module does not create private endpoints, DNS zones, a firewall or a hub DNS proxy.

## Usage

```hcl
module "network" {
  source              = "./modules/azure/network"
  name                = "vnet-management"
  resource_group_name = "rg-management"
  location            = "uksouth"
  address_space       = ["10.1.0.0/16"]
  subnets = {
    system = { address_prefixes = ["10.1.0.0/24"] }
  }
}
```

## Optional routing and naming overrides

Defaults create no route tables, routes or routing associations. To prepare an
unused table, supply an empty object such as `route_tables = { rt-reserved = {} }`.
Table names default to their map keys and BGP propagation defaults to `true`.
Each subnet can be associated with one table; multiple subnets can share a table.
Routes are keyed by name within each table and are managed as separate resources,
so removing a route from the map plans its deletion.

```hcl
# Add these arguments to the module call above.
network_security_group_name_prefix = "security-"
route_tables = {
  management = {
    name                          = "rt-management"
    bgp_route_propagation_enabled = false
    routes = {
      firewall = {
        address_prefix         = "0.0.0.0/0"
        next_hop_type          = "VirtualAppliance"
        next_hop_in_ip_address = "10.1.3.4"
      }
    }
  }
  rt-reserved = {}
}
route_table_subnet_associations = { system = "management" }
```

The next-hop IP above is illustrative; the caller must provision a reachable
appliance before associating that route table. An unused table does not change
traffic. AKS using forced egress also needs a compatible outbound configuration;
creating a route table alone does not change the cluster's outbound mode.

Override a single NSG's full name with `network_security_group_name` inside its
subnet object. Otherwise its name uses the configurable prefix plus the subnet key.
All routing and naming defaults live in `variables.tf`. Terraform provider source
and version constraints are static Terraform requirements, not module inputs.

## Private DNS links

Pass existing or separately managed zone names and their resource groups to
`private_dns_zone_links`. The module owns each link to its VNet; the caller owns
each zone, so multiple networks can link the same zone without competing over its
lifecycle. Registration defaults to disabled for private endpoint zones.

```hcl
private_dns_zone_links = {
  openai = {
    name                  = "management"
    resource_group_name   = "rg-management"
    private_dns_zone_name = "privatelink.openai.azure.com"
  }
}
```

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | required | Virtual network name. |
| `location` | `string` | required | Azure region. |
| `resource_group_name` | `string` | required | Existing resource group. |
| `address_space` | `list(string)` | required | VNet address ranges. |
| `private_dns_zone_links` | `map(object)` | `{}` | Optional links to caller-owned private DNS zones. |
| `subnets` | `map(object)` | required | Subnets keyed by Azure subnet name. |
| `network_security_group_name_prefix` | `string` | `"nsg-"` | Default NSG name prefix. Per-subnet names take precedence. |
| `route_tables` | `map(object)` | `{}` | Named tables with optional Azure names, BGP propagation and named routes. |
| `route_table_subnet_associations` | `map(string)` | `{}` | Subnet key to route table key. Both keys must exist in their input maps. |
| `tags` | `map(string)` | `{}` | Resource tags. |

Object field definitions are documented in `variables.tf`.

## Outputs

| Name | Description |
| --- | --- |
| `vnet_id` | Virtual network resource ID. |
| `private_dns_zone_link_ids` | Private DNS VNet link IDs keyed by logical name. |
| `subnet_ids` | Subnet resource IDs keyed by name, after NSG/routing configuration. |
| `route_table_ids` | Route table resource IDs keyed by logical name. |
| `network_security_group_ids` | NSG resource IDs keyed by subnet name. |
