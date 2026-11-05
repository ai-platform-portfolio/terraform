# Azure-to-Google workload identity federation

Creates a Google workload identity pool/provider, a service account, and a
caller-defined project IAM role. Trust is restricted to an exact Entra issuer,
audience, tenant, managed identity and application role. That identity may
impersonate only the created service account. No keys or passwords are created.

The caller supplies `name`, `project_id`, `tenant_id`, `principal_id`, `issuer`,
`audience`, `role_value` and the role definition:

```hcl
role = {
  id          = "objectReader"
  title       = "Object reader"
  description = "Read objects in the configured project."
  permissions = ["storage.objects.get"]
}
```

`name` is the service account ID and the pool name prefix. `provider_id` defaults
to `azure`. The module does not select application permissions or a target project.
Custom roles are project-scoped; callers own permission selection and any narrower
resource, service or application authorisation requirements.

The Entra audience and role assignment are caller-owned prerequisites. Outputs
provide the provider name, service account email and token-exchange metadata.
Callers implement Google STS exchange and service-account token acquisition;
this module does not acquire or renew credentials or configure network access.

Run `terraform init -backend=false`, `terraform validate` and `terraform test`
with Terraform 1.9+. Mocked tests check the exact identity trust and caller-defined
role metadata/permissions; they do not prove a real token exchange.

[Google's Azure federation documentation](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-other-clouds).
