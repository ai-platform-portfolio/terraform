# Kubernetes trust in an existing Google identity pool

Registers one OIDC provider and one `roles/iam.workloadIdentityUser` member on an
existing service account. The caller supplies exact issuer/audience/ServiceAccount
subject and existing project/pool/account references. Existing resources, other
trust providers and inference permissions keep their original owner.

Use this when adding a Kubernetes workload to an already managed foundation. The
sibling `workload-identity` module continues to own its complete Entra foundation;
its interface and resource addresses are unchanged. No create/skip selector or
service-account key is introduced.

```hcl
module "gateway_trust" {
  source                = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/gcp/workload-identity-provider?ref=<full-commit>"
  project_id            = var.google.project_id
  pool_id               = var.google.pool_id
  provider_id           = "management-aks"
  service_account_email = var.google.service_account_email
  trust = {
    issuer   = module.aks.oidc_issuer_url
    audience = "api://management-gateway-google"
    subject  = "system:serviceaccount:gateway:proxy"
  }
}
```

Use native Google provider authentication (ADC or supported federation). Consumer
GitOps owns the non-secret external-account JSON and projected short-lived token.
The returned provider name supplies its Google STS audience. Reapply updates issuer
trust after cluster recreation; cleanup deletes only these two objects. The parent
pool/account must remain available until trust cleanup completes. Existing project
APIs and inference permissions are prerequisites, not owned by this module.

Run native `tofu init -backend=false`, `tofu validate` and `tofu test` in this
module. Mock tests verify exact trust and membership; real token exchange and model
access require separate deployment acceptance.
