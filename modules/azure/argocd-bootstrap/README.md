# argocd-bootstrap

Installs the pinned official ArgoCD chart through Helm, waits for readiness and rolls back failed installs. Configure the Helm provider in the caller after AKS exists. The module installs no GitOps Applications and registers no workload clusters. Release settings remain Terraform-owned until an explicit state handover; do not simultaneously self-manage the release through ArgoCD.

## Usage

```hcl
# Configure the Helm provider against an already provisioned cluster.
module "argocd" {
  source        = "./modules/azure/argocd-bootstrap"
  chart_version = "10.10.5"
  values        = [file("argocd-values.yaml")]
}
```

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | `"argocd"` | Helm release name. |
| `namespace` | `string` | `"argocd"` | ArgoCD namespace. |
| `chart_version` | `string` | required | Explicit argo-cd chart version. |
| `values` | `list(string)` | `[]` | Ordered YAML Helm values documents; do not include credentials. |
| `timeout` | `number` | `900` | Release readiness timeout in seconds. |

Object field definitions are documented in `variables.tf`.

## Outputs

| Name | Description |
| --- | --- |
| `release_name` | ArgoCD Helm release name. |
| `namespace` | ArgoCD namespace. |
