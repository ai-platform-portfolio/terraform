# Terraform module library

Reusable infrastructure modules. The management deployment root lives in
[gitops/bootstrap](https://github.com/ai-platform-portfolio/gitops/tree/main/bootstrap).
Its state uses an external Azure Blob backend. Subsequent clusters have separate
deployment roots; this module library does not own deployment state.

| Module | Purpose |
| --- | --- |
| [container-app-environment](modules/azure/container-app-environment) | One Azure Container Apps Consumption environment |
| [container-app](modules/azure/container-app) | One HTTP app with managed identity, safe ingress defaults and optional managed HTTPS |
| [servicebus](modules/azure/servicebus) | Service bus namespace with named children and optional private endpoints |
| [eventhub](modules/azure/eventhub) | Event hubs namespace with named children and optional private endpoints |
| [eventgrid](modules/azure/eventgrid) | Event grid domain with named children and optional private endpoints |
| [managed-redis](modules/azure/managed-redis) | Azure managed redis instance with named children and optional private endpoints |
| [network](modules/azure/network) | VNet, named subnets, NSGs and optional route tables/routes |
| [aks-cluster](modules/azure/aks-cluster) | Entra-enabled AKS, control-plane identity, node pools and OIDC |
| [entra-application](modules/azure/entra-application) | Entra OIDC/OAuth clients and APIs, app roles, consent, federation and scoped Azure access |
| [entra-group](modules/azure/entra-group) | Entra security groups with explicit owners/members and optional scoped Azure roles |
| [apim](modules/azure/apim) | Private Standard v2 API Management with managed identity and VNet integration |
| [gcp/workload-identity](modules/gcp/workload-identity) | Keyless Azure-to-Google federation with caller-defined project permissions |
| [foundry](modules/azure/foundry) | Private AI Services account, projects, model deployments and inference RBAC |
| [kubernetes-fleet-manager](modules/azure/kubernetes-fleet-manager) | Hubless fleet for AKS inventory and multi-cluster upgrade orchestration |
| [managed-identity](modules/azure/managed-identity) | Workload identities, OIDC federated credentials and scoped role assignments |
| [postgresql-flexible-server](modules/azure/postgresql-flexible-server) | Private Azure PostgreSQL server with Entra-only authentication and administrators |
| [argocd-bootstrap](modules/azure/argocd-bootstrap) | Initial ArgoCD installation through Helm |

Modules are grouped by provider under `modules/<provider>/<name>/`.
Key Vault, storage-account and
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
Run `tofu fmt -check -recursive .` and `tofu init -backend=false` /
`tofu validate` in each module. CI performs these checks without Azure access.

CI discovers `modules/*/*` through the shared validation workflow, so new modules
are included without editing a directory list.

The Container Apps modules compose with the existing `managed-identity` module;
callers own resource groups, custom permissions, provider configuration and
instance repetition, following `gitops/bootstrap`. The portfolio root in `.github`
is an acceptance consumer. No hosting names, domains or AKS role definitions are
embedded in the modules. CI uses OpenTofu 1.13.9 and runs mocked native lifecycle
tests for Container Apps and the existing Foundry module. No Azure apply is run.
