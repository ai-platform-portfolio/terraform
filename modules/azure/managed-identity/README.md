# managed-identity

Creates a user-assigned managed identity and named OIDC federated credentials. Permissions are assigned by the caller at the smallest required resource scope. Federation must match the exact Kubernetes namespace and service account. No static credential is generated.

## Usage

```hcl
module "dns_identity" {
  source              = "./modules/azure/managed-identity"
  name                = "id-management-dns"
  resource_group_name = "rg-management"
  location            = "uksouth"
  federated_credentials = {
    external-dns = {
      issuer  = module.aks.oidc_issuer_url
      subject = "system:serviceaccount:external-dns:external-dns"
    }
  }
}
```

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | required | Managed identity name. |
| `resource_group_name` | `string` | required | Existing resource group. |
| `location` | `string` | required | Azure region. |
| `tags` | `map(string)` | `{}` | Resource tags. |
| `federated_credentials` | `map(object)` | `{}` | OIDC credentials keyed by name. |

Object field definitions are documented in `variables.tf`.

## Outputs

| Name | Description |
| --- | --- |
| `identity_id` | Identity resource ID. |
| `client_id` | Client ID for workload identity annotations. |
| `principal_id` | Principal ID for scoped RBAC assignments. |
