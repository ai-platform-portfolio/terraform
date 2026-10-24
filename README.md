# Terraform module library

Reusable infrastructure modules. The management deployment root lives in
[gitops/bootstrap](https://github.com/ai-platform-portfolio/gitops/tree/main/bootstrap).
Its state uses an external Azure Blob backend. Subsequent clusters have separate
deployment roots; this module library does not own deployment state.

| Module | Purpose |
| --- | --- |
| [network](modules/azure/network) | VNet, named subnets, NSGs and optional route tables/routes |
| [aks-cluster](modules/azure/aks-cluster) | Entra-enabled AKS, control-plane identity, node pools and OIDC |
| [entra-group](modules/azure/entra-group) | Entra security groups with explicit owners/members and optional scoped Azure roles |
| [managed-identity](modules/azure/managed-identity) | Workload identities, OIDC federated credentials and scoped role assignments |
| [argocd-bootstrap](modules/azure/argocd-bootstrap) | Initial ArgoCD installation through Helm |

Azure modules live under `modules/azure/<name>/`. Key Vault, storage-account and
DNS-zone modules are future extensions. The current management deployment uses
existing Azure services and manages its disposable application containers directly.

Consumers pin a full Git commit, for example:

```hcl
module "network" {
  source              = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/network?ref=<full-commit-sha>"
  name                = "vnet-management"
  resource_group_name = "rg-management"
  location            = "uksouth"
  address_space       = ["10.1.0.0/16"]
  subnets = {
    system = { address_prefixes = ["10.1.0.0/24"] }
  }
}
```

Provider configurations belong in callers. This repo never applies infrastructure.
Run `terraform fmt -check -recursive .` and `terraform init -backend=false` /
`terraform validate` in each module. CI performs these checks without Azure access.
