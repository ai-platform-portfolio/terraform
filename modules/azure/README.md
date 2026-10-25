# Azure Terraform modules

Reusable Azure modules live in `modules/azure/<module-name>/` within this library.

Each module contains `main.tf`, `variables.tf`, `outputs.tf`, and
a `README.md` documenting usage, inputs, outputs, and production considerations.

Deployment-specific configuration belongs in the
[GitOps bootstrap root](https://github.com/ai-platform-portfolio/gitops/tree/main/bootstrap).

- [Entra application](entra-application/README.md): application, service principal and workload federation for OIDC clients.

- [Kubernetes Fleet Manager](kubernetes-fleet-manager/README.md): shared hubless fleet; cluster roots own their memberships through the AKS module.
