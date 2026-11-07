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

References: [account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_account),
[model deployment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_deployment),
[private DNS](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns),
[processing scopes](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/deployment-types).


## Private endpoint provider migration

Requires Terraform 1.8+ and AzAPI 2.13+. Existing account/project/model resources
remain with AzureRM. The endpoint uses AzAPI with the same Network API and keeps
its dependency on all projects and deployments. Native retry matches only the
known `Account.*state Accepted` HTTP readiness error; it does not guarantee retry
of a successful HTTP response whose asynchronous operation later fails.
AzAPI attempts to read back an endpoint after create failure and retain its ID,
so a subsequent Terraform operation can manage it without bespoke CLI cleanup.

The `moved` block converts existing endpoint state without deleting the endpoint
or its NIC. The formerly embedded DNS zone group is now a separate AzAPI resource
and needs an import in the caller (Terraform permits import blocks only in root
modules). GitOps bootstrap supplies a conditional native import: import when
present, otherwise create normally. No existing resource may have two owners.
Other callers must import their existing group before applying an upgrade:

```hcl
import {
  to = module.foundry.azapi_resource.private_dns_zone_group
  id = "${module.foundry.private_endpoint_id}/privateDnsZoneGroups/${module.foundry.private_dns_zone_group_name}"
}
```

Review the migration plan: the endpoint must move in place and the DNS group must
be imported, without deletes/replacements. No apply or production migration was
performed during implementation. The original Azure
`InvalidResponseFromPrivateLinkService` error remains unreproduced after four
isolated comparisons; this change improves native state/error handling rather
than claiming to fix that service-side error.

Reference: Microsoft's [Cognitive Services module migration](https://github.com/Azure/terraform-azurerm-avm-res-cognitiveservices-account#modules),
[AzAPI create error handling](https://github.com/Azure/terraform-provider-azapi/blob/v2.13.0/internal/services/azapi_resource.go).
