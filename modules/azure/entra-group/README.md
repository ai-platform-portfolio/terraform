# Entra security group

Creates one assigned-membership Entra security group with explicit owners and
members. Optional scoped Azure RBAC assignments use the same `role_assignments`
map as the managed-identity module. Omitting the map grants no Azure roles.
The module does not grant Entra directory roles or make the group role-assignable.

```hcl
module "aks_admins" {
  source       = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/entra-group?ref=<full-commit-sha>"
  display_name = "aks-platform-admins"
  description  = "Administrators of the management AKS cluster."
  owners       = var.admin_group_owner_object_ids
  members      = var.admin_group_member_object_ids
}

# In the calling root, consume module.aks_admins.object_id when configuring AKS:
# admin_group_object_ids = [module.aks_admins.object_id]
```

For another use case, add scoped Azure roles to the same module call:

```hcl
role_assignments = {
  reader = {
    scope                = var.resource_group_id
    role_definition_name = "Reader"
  }
}
```

## Inputs and outputs

| Input | Type | Required |
| --- | --- | --- |
| `display_name` | string | Yes |
| `description` | string | Yes |
| `owners` | set(string) | Yes; at least one user or service-principal object ID |
| `members` | set(string) | Yes; use an empty set when no members are required |
| `role_assignments` | map of `{ scope, role_definition_name }` | No; defaults to an empty map |

`object_id` is the group's Entra object ID. Azure role assignments use that ID
with principal type `Group`. Owners are not automatically added as members.

## Authentication and ownership

Configure the `azuread` and `azurerm` providers in the calling root. The module
contains no provider configuration and does not require Azure CLI authentication.
The Terraform principal needs Microsoft Graph authority to create/manage the
group and its owners/members. Optional Azure role assignments additionally require
`Microsoft.Authorization/roleAssignments/write` at the requested scopes; group
ownership alone does not confer that Azure permission.

This module owns the complete owner/member lists and its declared Azure roles.
Do not manage the same memberships through separate `azuread_group_member`
resources. Existing groups require deliberate import and review of their current
membership; matching display names are rejected instead of silently adopted.
Entra group names are not globally unique, so the duplicate-name check is a
provider preflight, not a directory uniqueness guarantee. Group membership and
Azure role changes can take time to propagate before AKS access succeeds.

Keep deployment-specific principal IDs in private caller inputs. The module
library stores no deployment state and performs no automatic apply.

References: [Entra group resource](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group),
[Azure role assignments](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment).
