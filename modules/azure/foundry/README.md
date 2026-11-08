# Private Microsoft Foundry inference

Creates an AIServices account with project management enabled, parameterized model
deployments and projects, a private endpoint and optional account-scoped RBAC. The caller owns
the resource group, shared user-assigned identity, subnet, NSG and private DNS.
No account keys are output. The defaults disable local authentication and public
access, deny public network traffic, and use a user-assigned identity. Account,
network ACL, identity, private endpoint and RBAC settings are exposed as inputs;
review any override that weakens these defaults.

Pass `role_assignments` as a map keyed by stable assignment purpose. Each entry
needs only `principal_id` and `role_definition_name`. The module scopes every
assignment to the Foundry account; projects inherit the grants. Azure resolves
the principal type, and normal Entra checks apply. The default empty map creates
no assignments. Do not let another controller manage the same role grant.

```hcl
role_assignments = {
  administrators = {
    principal_id         = data.azuread_group.administrators.object_id
    role_definition_name = "Foundry Owner"
  }
}
```

This replaces the previous singleton `inference_*` inputs and
`skip_service_principal_aad_check`. Existing consumers with a managed assignment
must explicitly plan its state/address transition before adopting this interface.

For selected-IP public access, set `account_settings.public_network_access_enabled`
to `true` and supply `network_acls.ip_rules` as public IPv4 addresses or CIDRs.
The default action remains `Deny` and bypass remains `None`; local authentication
stays disabled unless explicitly overridden. The private endpoint remains present.
`network_acls` is sensitive to redact addresses in normal Terraform plans. Values
still exist in Terraform state and saved plans; protect those artifacts. The
module defaults remain private-only with no IP rules.

Supply all three Foundry private DNS zones: `privatelink.openai.azure.com`,
`privatelink.cognitiveservices.azure.com` and `privatelink.services.ai.azure.com`.
Place the private endpoint in its VNet region, which may differ from the Foundry
account region. Permit only approved clients to reach its subnet on TCP 443.

Deployment names are stable map keys; model names, versions, SKUs, capacity and
operation timeouts are caller inputs. Automatic model upgrades are disabled by
default. Only `Standard` is approved by default; changing the SKU allowlist is a
processing-scope decision, not simply a resource-location change. Live quota and
model availability must be checked before selecting a deployment.

The module provisions inference infrastructure. Gateway APIs, cross-cloud
federation, private transport and runtime validation are separate dependencies.
No agent compute, search service or storage is provisioned for inference-only use.

References: [account](https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/2026-03-01/accounts),
[model deployment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_deployment),
[private DNS](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns),
[processing scopes](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/deployment-types).


## Native lifecycle handling

The account, private endpoint and DNS group use AzAPI 2.13+. Projects and model
deployments remain with AzureRM. Dependencies order destruction as DNS group,
endpoint, models, projects, account, then purge. Creation uses the reverse order;
the destroy-time purge action makes no API request during creation.

The endpoint is replaced when the account ID is planned to change. An account
replacement can reuse the same ARM ID while Azure deletes its old private-link
connection; retaining the endpoint then leaves it `Disconnected` and removes its
DNS record. Referencing the account ID avoids replacing the endpoint for ordinary
in-place account changes, such as an IP allowlist update. The dependent DNS zone
group is replaced with the endpoint. For an account already replaced before this
rule was installed, repair the existing disconnected endpoint with a reviewed,
one-time Terraform `-replace` plan; the new rule cannot retroactively detect that
past account change.

Account operations retry only the observed `RequestConflict` response containing
`provisioning state is not terminal`, within the operation timeout. This handles
an HTTP conflict; it does not guarantee recovery from a failed asynchronous
operation. The endpoint separately retries the known account-not-ready HTTP error.

`purge_on_destroy` defaults to `true`, preserving permanent cleanup after account
deletion. Set it to `false` to retain Azure's soft-delete recovery window. Purge
uses the declared account location, group and name, and ignores an already absent
record. The delete timeout also bounds purge; AzAPI 2.13's action executor uses
its `create` timeout even for a destroy-time action. No CLI hook or state migration
is included. Existing AzureRM account state needs separate ownership transfer;
a fresh installation needs no migration.

References: [native retry](https://registry.terraform.io/providers/Azure/azapi/latest/docs/guides/feature_customized_retry),
[destroy-time actions](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource_action),
[account purge](https://learn.microsoft.com/en-us/rest/api/microsoftfoundry/accountmanagement/deleted-accounts/purge?view=rest-microsoftfoundry-accountmanagement-2025-06-01).
