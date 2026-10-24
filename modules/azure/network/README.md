# network

Creates a virtual network, named subnets, an NSG per subnet, and optional route tables, routes and subnet associations. NSGs retain Azure default rules and accept optional per-subnet `security_rules`; private endpoints and DNS links are future extensions. No firewall or hub DNS proxy is created.

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

## Optional security rules

Each subnet accepts a `security_rules` map keyed by Azure rule name. Omitting it
creates no custom rules. Rules are separate resources; removing a map entry plans
its deletion. Do not also manage these rules inline on the same NSG.

For a subnet hosting public HTTP/S ingress, add this inside its subnet object:

```hcl
security_rules = {
  public-web = {
    description                = "Allow public HTTP/S load balancer traffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}
```

Subnet and NIC NSGs both filter traffic. An AKS-managed NIC rule cannot override
a subnet NSG's default inbound deny. Permit only the service ports required by
that deployment; keep AKS-managed NIC filtering in place. Rule priorities must be
unique within each NSG and direction. Consumers of `subnet_ids` wait for configured
security rules as well as routing and NSG associations.

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

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | required | Virtual network name. |
| `location` | `string` | required | Azure region. |
| `resource_group_name` | `string` | required | Existing resource group. |
| `address_space` | `list(string)` | required | VNet address ranges. |
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
| `subnet_ids` | Subnet resource IDs keyed by name, after NSG/routing configuration. |
| `route_table_ids` | Route table resource IDs keyed by logical name. |
| `network_security_group_ids` | NSG resource IDs keyed by subnet name. |
