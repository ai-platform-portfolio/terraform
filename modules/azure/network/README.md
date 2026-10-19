# network

Creates a virtual network, named subnets and an NSG per subnet. NSGs use Azure default rules; custom ingress/egress, route tables, private endpoints and DNS links are future extensions. No firewall or hub DNS proxy is created.

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

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | required | Virtual network name. |
| `location` | `string` | required | Azure region. |
| `resource_group_name` | `string` | required | Existing resource group. |
| `address_space` | `list(string)` | required | VNet address ranges. |
| `subnets` | `map(object)` | required | Subnets keyed by Azure subnet name. |
| `tags` | `map(string)` | `{}` | Resource tags. |

Object field definitions are documented in `variables.tf`.

## Outputs

| Name | Description |
| --- | --- |
| `vnet_id` | Virtual network resource ID. |
| `subnet_ids` | Subnet resource IDs keyed by name, after NSG association. |
