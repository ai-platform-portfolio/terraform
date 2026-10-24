# Entra application

Reusable Microsoft Entra application registration and enterprise service principal
for portfolio portals, APIs and automation clients. Configure only the features a
caller needs. The module owns the registration, principal and explicitly requested
assignments/grants; it does not adopt existing applications by display name.

| Area | Inputs |
| --- | --- |
| Identity | `display_name`, `description`, `owners`, `prevent_duplicate_names` |
| Sign-in | `sign_in_audience`, `service_principal.account_enabled`, `service_principal.assignment_required` |
| Clients | `web`, `spa_redirect_uris`, `public_client_redirect_uris`, `fallback_public_client_enabled` |
| Token claims | `group_membership_claims`, `optional_claims` |
| Exposed API | `identifier_uris`, `api`, `app_roles` |
| Requested API access | `required_resource_access` |
| Inbound access | `app_role_assignments` for users, groups and service principals |
| Explicit outbound consent | `application_permission_grants`, `delegated_permission_grants` |
| Workload authentication | `federated_credentials` |
| Azure resource access | `role_assignments` |

`variables.tf` documents the exact types and defaults. All maps/sets of optional
permissions, grants, roles, assignments and federations default to empty. Web/API
and optional-claim objects default to `null`. A minimal call creates only the
application and service principal. The default audience is single-tenant, duplicate
display names are rejected, the enterprise principal is enabled, assignments are
not required, and public-client fallback and implicit grants are disabled.

## Portal with workload federation and group access

```hcl
module "portal" {
  source       = "./modules/azure/entra-application"
  display_name = "portfolio-portal"
  description  = "Developer portal sign-in"
  owners       = [data.azurerm_client_config.current.object_id]

  web = {
    redirect_uris = ["https://portal.example.com/api/auth/oidc/handler/frame"]
    homepage_url  = "https://portal.example.com"
    logout_url    = "https://portal.example.com/logout"
  }

  service_principal = { assignment_required = true }
  group_membership_claims = ["ApplicationGroup"]
  optional_claims = {
    id_token = [{ name = "email" }]
  }

  app_roles = {
    Admin = {
      # Generate once and keep stable when renaming the app or changing its URL.
      id           = "11111111-1111-4111-8111-111111111111"
      display_name = "Portal administrator"
      description  = "Manage the portal"
    }
  }

  app_role_assignments = {
    platform_admins = {
      principal_object_id = module.platform_admins.object_id
      role                = "Admin"
    }
  }

  federated_credentials = {
    portal = {
      issuer  = module.aks.oidc_issuer_url
      subject = "system:serviceaccount:portal:portal-server"
    }
  }
}
```

The application must support federated client assertions; registration alone does
not make arbitrary OIDC clients support secretless authentication. Argo CD is one
supported caller. Configure the service account's projected token and the client's
OIDC settings separately. The default federation audience is
`api://AzureADTokenExchange`; override it for a different trusted token issuer.

Setting `assignment_required = true` without any assignments intentionally prevents
user sign-in. Groups use the `User` app-role member type; assigning groups may
require Entra licensing and does not expand nested group membership. Group claims
and app roles are distinct token claims. `ApplicationGroup` emits assigned groups;
`SecurityGroup` emits security-group memberships subject to token limits. The
application must enforce authorization using the expected claim.

For an application exposing no app roles, omit `role` in an assignment to use the
provider's all-zero default-access role. With exposed roles, select an `app_roles`
key explicitly. Stable map keys preserve assignment resource addresses.

## API and automation client

```hcl
module "catalog_api" {
  source          = "./modules/azure/entra-application"
  display_name    = "portfolio-catalog-api"
  owners          = [data.azurerm_client_config.current.object_id]
  identifier_uris = [var.catalog_api_identifier_uri]

  api = {
    scopes = {
      "Catalog.Read" = {
        id                         = "22222222-2222-4222-8222-222222222222"
        admin_consent_display_name = "Read catalog"
        admin_consent_description  = "Read the portfolio catalog as a signed-in user"
      }
    }
  }

  app_roles = {
    "Catalog.Read.All" = {
      id                   = "33333333-3333-4333-8333-333333333333"
      display_name         = "Read all catalog entries"
      description          = "Read the catalog without a signed-in user"
      allowed_member_types = ["Application"]
    }
  }
}

module "catalog_client" {
  source       = "./modules/azure/entra-application"
  display_name = "portfolio-catalog-client"
  owners       = [data.azurerm_client_config.current.object_id]

  required_resource_access = {
    catalog = {
      resource_app_id = module.catalog_api.client_id
      permissions = {
        read = {
          id   = module.catalog_api.app_role_ids["Catalog.Read.All"]
          type = "Role"
        }
      }
    }
  }

  # Explicit admin consent, separate from the manifest request above.
  application_permission_grants = {
    catalog_read = {
      resource_principal_id = module.catalog_api.principal_id
      app_role_id           = module.catalog_api.app_role_ids["Catalog.Read.All"]
    }
  }

  federated_credentials = var.catalog_client_federated_credentials
}
```

`Role` requests an application permission; `Scope` requests a delegated permission.
Declaration in `required_resource_access` alone does not grant access. The example
explicitly grants application consent. For delegated consent, configure
`delegated_permission_grants` with the target service principal, scope names and
optionally a user object ID. **Omitting the user grants consent for all tenant
users.** No consent grant is created unless its input map is populated.

API scope and app-role map keys become token claim values. Supply distinct, stable
UUIDs; do not regenerate them on each plan. Role/scope values must not overlap.
Exposed API tokens default to version 2 when `api` is configured. Accepting personal
Microsoft accounts requires that version explicitly through `api`. Identifier URIs
must satisfy the tenant's verified-domain and application-ID URI policies.

For an SPA use `spa_redirect_uris`; for a native CLI use
`public_client_redirect_uris`. Keep callbacks registered under their correct client
type. Enable public-client fallback only for flows needing no redirect, such as
device code. Legacy implicit-grant switches are explicit options under `web`;
prefer authorization code with PKCE where the client supports it.

## Azure roles and credentials

`role_assignments` grants named Azure roles at explicit scopes to this application's
service principal, using the same map shape as `managed-identity` and `entra-group`:

```hcl
role_assignments = {
  state = {
    scope                = module.state_account.id
    role_definition_name = "Storage Blob Data Contributor"
  }
}
```

These are Azure RBAC roles, not directory roles or OIDC app roles. Configuring a
role requires an authenticated AzureRM provider and authority over that scope.
An empty role map creates no Azure assignments.

No passwords, private keys or certificates are generated. Prefer federation;
clients requiring another credential can compose a separately owned credential
resource using `application_id`, with its state/rotation implications reviewed by
the caller. Nothing in this module copies credentials into Key Vault or outputs
secrets. SAML enterprise-app setup, conditional access and directory-role grants
are outside this OIDC/OAuth application module; `saml2_token` optional claims alone
do not configure SAML sign-in.

## Outputs, permissions and lifecycle

| Output | Purpose |
| --- | --- |
| `client_id` | Application/client ID for OIDC or requested-resource configuration |
| `object_id` | Application object ID |
| `application_id` | Provider resource ID for composing application resources |
| `principal_id` | Enterprise service principal object ID for grants and Azure roles |
| `app_role_ids` | Exposed role UUIDs keyed by token value |
| `oauth2_permission_scope_ids` | Exposed delegated scope UUIDs keyed by token value |

No tenant/subscription IDs or credentials are outputs. Outputs identify resources;
consumers that must wait for *all* federation/grants should depend on the whole
module. Configuring grant/role maps can add permissions beyond app creation.

The AzureAD provider uses Microsoft Graph. Creating applications, service
principals and federation needs directory authority; subscription Contributor is
insufficient. Application-role assignments/admin consent require additional
Graph/directory permissions. Delegated consent can require Global Administrator
or the documented equivalent application permissions. Review the exact provider
resource permissions for the caller's authentication method.

Import existing applications and service principals into their module addresses
before adoption; a duplicate-name check does not import them. Do not manage the
same app properties through separate standalone resources. Disable a role/scope
before removing it where Entra requires that lifecycle; remove its assignments
first. Deletion removes module-owned grants, assignments, principal, federation and
application. Requested foreign APIs and assigned users/groups are not owned here.

Validate with `terraform init -backend=false` and `terraform validate`; the library's
wildcard CI includes this module. Provider validation and plan assertions do not
prove tenant consent, licensing, effective access, client sign-in or rotation.

Sources: [application](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application),
[app assignments and application consent](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/app_role_assignment),
[delegated consent](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal_delegated_permission_grant),
[federation](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential).
