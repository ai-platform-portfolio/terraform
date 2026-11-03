# postgresql-flexible-server

Creates one Azure PostgreSQL Flexible Server with Microsoft Entra-only
authentication, named Entra administrators and a private endpoint. The caller
supplies an existing resource group, endpoint subnet and PostgreSQL private DNS
zone. The module does not create databases, SQL roles, application identities or
federated credentials; application delivery owns their separate lifecycles.

The management caller will pass its existing AKS administrator group as a `Group`
administrator. A generic caller can provide any supported Entra principal:

```hcl
module "postgres" {
  source                     = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/postgresql-flexible-server?ref=<full-commit-sha>"
  name                       = var.postgres.name
  resource_group_name        = azurerm_resource_group.this.name
  location                   = var.azure.location
  tenant_id                  = sensitive(data.azurerm_client_config.current.tenant_id)
  postgres_version           = var.postgres.version
  sku_name                   = var.postgres.sku_name
  storage_mb                 = var.postgres.storage_mb
  private_endpoint_subnet_id = module.network.subnet_ids[var.postgres.endpoint_subnet_key]
  private_dns_zone_id        = azurerm_private_dns_zone.private["postgres"].id

  entra_administrators = {
    aks_admins = {
      object_id      = module.aks_admin_group.object_id
      principal_name = var.aks.admin_group.display_name
      principal_type = "Group"
    }
  }

  tags = var.azure.tags
}
```

The caller reads `data.azurerm_client_config.current` once at the top of its
`main.tf` and passes the tenant ID to this module. It should use
`privatelink.postgres.database.azure.com` for the private
endpoint DNS zone and link that zone to the workload VNet. Public network and
password authentication are disabled. PostgreSQL clients must request an Entra
token for the Azure PostgreSQL audience and verify the server's TLS certificate;
Azure Flexible Server does not support client-certificate authentication.

Entra server administration is distinct from SQL role provisioning: a database
administrator must still create SQL roles mapped to each application identity.
Do not give the AKS administrator group to application pods. This module does
not create or retain a password or output tenant/subscription identifiers.

Run `terraform fmt -check` and `terraform init -backend=false` /
`terraform validate` in this directory. These checks do not provision Azure
resources or prove private DNS, Entra sign-in or application connectivity.
