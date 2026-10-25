# Private Microsoft Foundry inference

Creates an AIServices account with project management enabled, parameterized model
deployments and projects, a private endpoint and account-scoped inference RBAC. The caller owns
the resource group, shared user-assigned identity, subnet, NSG and private DNS.
No account keys are output. The defaults disable local authentication and public
access, deny public network traffic, and use a user-assigned identity. Account,
network ACL, identity, private endpoint and RBAC settings are exposed as inputs;
review any override that weakens these defaults.

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

References: [account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_account),
[model deployment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_deployment),
[private DNS](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns),
[processing scopes](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/deployment-types).
