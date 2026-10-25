# kubernetes-fleet-manager

Creates a **hubless** Azure Kubernetes Fleet Manager in an existing resource
group. It groups supported clusters for inventory and Kubernetes/node-image
upgrade orchestration. It does not create AKS clusters or install applications.
Argo retains package reconciliation; no additional hub cluster is provisioned.

## Usage

```hcl
module "fleet" {
  source              = "./modules/azure/kubernetes-fleet-manager"
  name                = "fleet-platform"
  location            = "uksouth"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# In the existing AKS module call:
# fleet_membership = {
#   fleet_id = module.fleet.id
#   name     = "management"
#   group    = "management"
# }
```

Inputs: required string `name`, `location`, `resource_group_name`; optional map of
strings `tags` (default `{}`). Outputs: `id`, `name`. Provider configuration and
authentication belong to the caller. No credentials or Entra application are
created by this module.

Each cluster root uses the AKS module's optional `fleet_membership` input. Do not
put all members in the shared fleet root: a cluster root must own detachment
before its own AKS deletion. Destroy workload roots before the shared fleet root.
Deleting the fleet is not a way to destroy member AKS clusters. Existing fleets
and members require an explicit Terraform import; this module does not adopt them
by name.

The deployment identity needs Azure management-plane permissions for Fleet
creation, membership creation/deletion and the joined AKS resource, including
applicable `Microsoft.ContainerService/fleetMemberships` operations. Use the
current Azure documented permissions for the selected API. An Entra application
registration or Microsoft Graph consent does not grant these Azure RBAC rights.
Crossplane's AzureAD provider manages service directory resources; it cannot
bootstrap its own initial permissions. No new tenant-wide Graph consent is
required just to create this fleet and membership.

This module intentionally provides no hub, resource placement, fleet namespace,
upgrade strategy, upgrade run, networking or preview features. Those are separate
capabilities; do not enable a second reconciler for Argo-owned resources. The
AzureRM Fleet resource uses its supported hubless API; hub-enabled deployment
needs a separate API/provider assessment rather than deprecated `hub_profile`.

Sources: [fleet options](https://learn.microsoft.com/en-us/azure/kubernetes-fleet/concepts-choosing-fleet),
[creation and membership permissions](https://learn.microsoft.com/en-us/azure/kubernetes-fleet/quickstart-create-fleet-and-members-portal),
[AzureRM Fleet Manager](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_fleet_manager),
[AzureRM Fleet Member](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_fleet_member).
