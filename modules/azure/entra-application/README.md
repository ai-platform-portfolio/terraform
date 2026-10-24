# Entra application

Creates an Entra application registration, its service principal and an optional
map of federated identity credentials. Configure web/native callbacks and group
claims at the caller. No application password or certificate is created.

```hcl
module "portal_sso" {
  source       = "./modules/azure/entra-application"
  display_name = "portal"
  owners       = [data.azurerm_client_config.current.object_id]

  group_membership_claims      = ["SecurityGroup"]
  web_redirect_uris           = ["https://portal.example.com/auth/callback"]
  public_client_redirect_uris = ["http://localhost:8085/auth/callback"]

  federated_credentials = {
    portal = {
      issuer  = module.aks.oidc_issuer_url
      subject = "system:serviceaccount:portal:portal-server"
    }
  }
}
```

The default audience is single-tenant (`AzureADMyOrg`). The service principal has
no Azure role assignments or application-assignment requirement; application RBAC
must explicitly authorize users/groups. Group claims alone do not grant access.
Web/native callback sets and the federation map can be empty. Outputs expose the
application client/object IDs and the service principal ID; they contain no tenant
or subscription metadata. Callers requiring all federation to exist before a
consumer starts should depend on the module as a whole.

This module uses Microsoft Graph through the AzureAD provider, not Azure ARM.
The caller needs authority to create applications, service principals and
federated credentials. Azure subscription Contributor alone is insufficient.
Group-overage handling, API consent and user/group assignments are application
specific and are not configured here. Deleting this module deletes its registration,
service principal and federated credentials.
