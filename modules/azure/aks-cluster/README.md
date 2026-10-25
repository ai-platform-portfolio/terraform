# aks-cluster

Creates AKS with Entra group-based Kubernetes RBAC, disabled local accounts, a user-assigned control-plane identity, subnet-scoped Network Contributor roles, system and optional application pools, OIDC and workload identity. Azure CNI overlay and max_pods=110 avoid allocating one VNet address per pod. API access requires explicit CIDRs. The system pool is tainted; supply a user pool for applications. The caller needs role-assignment permissions. Free tier and one system node are portfolio simplifications; production requires appropriate replicas, zones, SLA and upgrade capacity. Service/pod ranges must not overlap connected networks.

## Usage

```hcl
module "aks" {
  source                 = "./modules/azure/aks-cluster"
  name                   = "aks-management"
  resource_group_name    = "rg-management"
  location               = "uksouth"
  tenant_id              = var.tenant_id
  kubernetes_version     = var.kubernetes_version
  vnet_subnet_id         = module.network.subnet_ids["system"]
  admin_group_object_ids = var.admin_group_object_ids
  authorized_ip_ranges   = var.authorized_ip_ranges
  user_node_pools = {
    platform = {
      vm_size        = "Standard_D2s_v5"
      node_count     = 1
      vnet_subnet_id = var.user_subnet_id
    }
  }
}
```

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | required | AKS cluster name. |
| `location` | `string` | required | Azure region. |
| `resource_group_name` | `string` | required | Existing resource group. |
| `tenant_id` | `string` | required | Entra tenant ID. |
| `kubernetes_version` | `string` | required | Explicit AKS Kubernetes version supported in the target region. |
| `vnet_subnet_id` | `string` | required | System node pool subnet resource ID. |
| `admin_group_object_ids` | `list(string)` | required | Entra security groups granted Kubernetes cluster admin. |
| `authorized_ip_ranges` | `list(string)` | required | CIDRs allowed to access the public AKS API, including the deployment runner. |
| `system_node_pool` | `object` | `{}` | Fixed-size system pool; applications use a separate user pool. |
| `user_node_pools` | `map(object)` | `{}` | Application pools keyed by AKS pool name (up to 12 lowercase alphanumeric characters). |
| `max_pods` | `number` | `110` | Explicit per-node pod capacity. |
| `sku_tier` | `string` | `"Free"` | Free for portfolio; Standard for an API uptime SLA. |
| `private_cluster_enabled` | `bool` | `false` | Use a private API; requires deployment runner network connectivity. |
| `pod_cidr` | `string` | `"10.244.0.0/16"` | Azure CNI overlay pod range; must not overlap connected networks. |
| `service_cidr` | `string` | `"10.240.0.0/16"` | Kubernetes service range; must not overlap connected networks. |
| `dns_service_ip` | `string` | `"10.240.0.10"` | DNS IP within the service range. |
| `tags` | `map(string)` | `{}` | Resource tags. |

Object field definitions are documented in `variables.tf`.

## Outputs

| Name | Description |
| --- | --- |
| `cluster_id` | AKS resource ID. |
| `cluster_name` | AKS cluster name. |
| `oidc_issuer_url` | Issuer for workload federation. |
| `kubelet_identity` | AKS kubelet identity. |
| `host` | Sensitive Kubernetes API endpoint, after node pool provisioning. |
| `cluster_ca_certificate` | Sensitive decoded CA certificate, after node pool provisioning. |

## Existing container registries

Set `container_registries` to a map of existing registry ARM IDs. The module grants
its AKS-managed kubelet identity `AcrPull` at each registry scope, without creating
another identity or a registry password. An empty map creates no assignments.
This uses registry-level RBAC; registries configured for ABAC repository permissions
require the corresponding repository role instead of `AcrPull`.

```hcl
container_registries = {
  platform = data.azurerm_container_registry.platform.id
}
```

## Automatic Fleet enrollment

Set `fleet_membership` when creating a cluster to enroll it automatically:

```hcl
fleet_membership = {
  fleet_id = module.fleet.id
  name     = "management"
  group    = "management"
}
```

The default `null` creates no membership and preserves existing callers. Each
cluster root owns its own membership. For a fleet owned in a different root,
supply its ARM ID from deployment automation rather than creating a second fleet.
The fleet and member can be in different regions or subscriptions in the same
Entra tenant. Cross-subscription enrollment requires the caller's Azure RBAC
permissions on both resources.

Terraform creates membership after AKS and removes it before deleting AKS.
Enrollment does not install GitOps packages, move workloads or start an upgrade.
The `group` is an update-ring label; it has no execution effect without an update
strategy and run. No upgrade policy is created here. Keep the shared fleet alive
until every cluster root has detached its membership.

`fleet_membership_id` is the member resource ID, or `null` without enrollment.
Changing the member name, fleet or cluster recreates the membership, not AKS.
Do not also declare the same membership in another module, ASO or Crossplane.
