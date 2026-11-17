# AWS identity for a Kubernetes workload

Creates one OIDC provider, one IAM role and one inline permission policy. The
caller supplies an exact issuer/audience/ServiceAccount subject and native IAM
policy JSON. Another foundation can consume the module unchanged with its own issuer, trust
and permissions. Existing identity providers and roles remain separately owned.

```hcl
module "workload" {
  source = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/aws/workload-identity?ref=<full-commit>"
  name   = "management-inference"
  trust = {
    issuer   = module.aks.oidc_issuer_url
    audience = "sts.amazonaws.com"
    subject  = "system:serviceaccount:gateway:proxy"
  }
  policy = jsonencode(var.workload_permissions)
}
```

The consumer mounts a short-lived projected token and uses native AWS SDK web
identity authentication. No key or exchange helper is provisioned. Use native AWS
provider operator authentication independently of this runtime role. The caller
must have permission to manage these three IAM resources.

An OIDC provider is unique per issuer in an AWS account. This module owns one
provider and one workload role together; reuse an already-owned provider through
its owning configuration rather than declaring this module twice for the same
issuer. Do not import an existing provider without an explicit ownership transfer.

Reapply updates trust after cluster recreation. The issuer dependency orders role
cleanup before cluster destruction; the inline policy is removed before the role.
Run `tofu init -backend=false`, `tofu validate` and `tofu test`. Mocked trust tests
are source evidence; real token refresh and service access need live acceptance.
