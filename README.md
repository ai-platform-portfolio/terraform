# Terraform module library

Reusable infrastructure modules. Deployments and Terraform state belong in the
[bootstrap repository](https://github.com/ai-platform-portfolio/bootstrap).

| Module | Purpose |
| --- | --- |
| [network](modules/azure/network) | VNet, named subnets, NSGs and optional route tables/routes |
| [aks-cluster](modules/azure/aks-cluster) | Entra-enabled AKS, control-plane identity, node pools and OIDC |
| [managed-identity](modules/azure/managed-identity) | Workload identities and OIDC federated credentials |
| [argocd-bootstrap](modules/azure/argocd-bootstrap) | Initial ArgoCD installation through Helm |

Azure modules live under `modules/azure/<name>/`. Key Vault, storage and DNS
modules will be added when their consumers are implemented.

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
