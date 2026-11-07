# Private Microsoft Foundry inference

Creates an AIServices account with project management enabled, parameterized model
deployments and projects, a private endpoint and optional account-scoped inference RBAC. The caller owns
the resource group, shared user-assigned identity, subnet, NSG and private DNS.
No account keys are output. The defaults disable local authentication and public
access, deny public network traffic, and use a user-assigned identity. Account,
network ACL, identity, private endpoint and RBAC settings are exposed as inputs;
review any override that weakens these defaults.

Set `inference_principal_id` to create the account-scoped inference assignment.
Leave it unset if a GitOps identity controller owns that assignment; do not let
two controllers manage the same Azure role grant.

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
