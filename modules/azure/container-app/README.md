# Container App

One HTTP Container App in a caller-owned Consumption environment, with a
caller-owned user-assigned identity. Use the existing `managed-identity` module
for identity and scoped grants. The caller owns any runtime-specific custom role,
environment variables and dependencies; this module contains no AKS or workload
registration logic. Repeat module calls with caller-owned `for_each` when needed.

Required inputs: `name`, `resource_group_name`, `container_app_environment_id`,
`managed_identity_id`, and an immutable `image` reference. Outputs: `id`, `fqdn`,
`url`. Optional inputs and their descriptions are in [variables.tf](variables.tf).

Defaults are internal HTTP ingress on port 8080, HTTPS-only transport, one revision,
0.25 vCPU / 0.5 GiB, `/healthz` probes and replica bounds 0–1. Set
`external_ingress_enabled = true` for public ingress and `replicas = { min = 1 }`
for a warm instance. A non-null `registry_server` uses managed identity; the caller
must grant AcrPull before app creation. No registry password is created.

```hcl
module "application" {
  source                       = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/container-app?ref=<full-commit-sha>"
  name                         = var.application.name
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = module.environment.id
  managed_identity_id          = module.identity.identity_id
  image                        = var.image
  registry_server              = data.azurerm_container_registry.existing.login_server
  replicas                     = { min = 1 }
  external_ingress_enabled     = true

  custom_domain = {
    hostname            = var.application.hostname
    zone_name           = data.azurerm_dns_zone.existing.name
    resource_group_name = data.azurerm_dns_zone.existing.resource_group_name
  }

  environment_variables = var.environment_variables
}
```

`custom_domain` is optional and supports one subdomain in an existing Azure DNS
zone. Public ingress is required for Azure-managed certificate validation. The
module owns this app's complete custom-domain list; do not manage extra hostnames
on the same app elsewhere. DNS must point directly to the generated app hostname.
Azure issues and renews the certificate; no private key is stored in configuration.

AzureRM creates the CNAME, verification TXT, domain registration and managed
certificate in dependency order. Its custom-domain certificate argument cannot
accept managed-certificate IDs, so Azure's AzAPI provider binds that certificate.
A scoped destroy-only PATCH removes the binding before certificate deletion,
including certificate replacement. `azapi_update_resource` alone does nothing
on destroy and would leave the certificate bound. The unbind tolerates an already
missing app. HTTP settings, replica bounds and DNS names stay caller-derived.

Run `tofu init -backend=false`, `tofu validate` and `tofu test`. Tests use mocked
providers, covering private defaults, optional HTTPS wiring, another caller's
names and invalid intent. They do not prove Azure issuance, renewal or cleanup.
