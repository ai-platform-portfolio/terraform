# eventhub

Creates one Event Hubs namespace. Parent repetition belongs to the caller's
module `for_each`; this module never loops its parent resource. Provide an
existing resource group and region. It owns no provider configuration or state.

```hcl
module "service" {
  source = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/eventhub?ref=<full-commit-sha>"

  name                = var.service_name
  resource_group_name = var.resource_group_name
  location            = var.location

  eventhubs = { events = {} }
  consumer_groups = { worker = { eventhub_key = "events" } }

  private_endpoints = {
    workload = {
      subnet_id            = var.endpoint_subnet_id
      private_dns_zone_ids = [var.private_dns_zone_id]
    }
  }

  tags = var.tags
}
```

Event hubs, consumer groups, parent-scoped Azure RBAC and private endpoints use
keyed maps. A consumer group references `eventhub_key`; names default to map keys.
The namespace defaults to Standard, one throughput unit. Basic cannot use private
endpoints, firewall rules or separately managed consumer groups. Auto inflate
requires Standard and an explicit `maximum_throughput_units`.

Each hub defaults to two partitions and 24-hour Delete retention using
`retention_description`. For Compact retention, set `cleanup_policy = "Compact"`,
`retention_time_in_hours = null` and supply tombstone retention when needed.
Partition reductions are unsupported; increases and retention limits depend on
the tier. The module references hubs using `namespace_id`, avoiding AzureRM 4.x's
deprecated hub arguments. Consumer groups still use their documented,
nondeprecated `namespace_name`, `eventhub_name` and `resource_group_name` fields.

Capture is optional. Its destination defaults to managed-identity authentication,
Avro and five-minute capture windows. Provide existing storage/container resources,
enable the matching namespace identity, and grant it Storage Blob Data Contributor
before creating capture-enabled hubs. A caller-owned user-assigned identity allows
that ordering without a dependency cycle. The module does not create storage or
its access grants. Azure cannot remove a namespace identity once assigned.

SAS authorization rules, dedicated clusters and disaster-recovery pairings are
outside this module. `dedicated_cluster_id` can reference an existing cluster.
Use child ID outputs for caller-managed entity-scoped RBAC; module RBAC is scoped
to the namespace.

Private endpoints default to subresource `namespace`. Use existing DNS zone
`privatelink.servicebus.windows.net` and link it to client VNets in the caller. DNS zone
creation/linking is outside this module. Empty `private_endpoints` creates no
endpoint; private-only defaults then intentionally provide no client network path.
Adding an endpoint does not itself disable public access.

Endpoint names default to `<parent-name>-<map-key>`; explicit names, connection
names, location/resource group, tags, manual approval and static IP configurations
can be overridden per entry. Endpoint location must match its VNet. DNS grouping is
omitted when `private_dns_zone_ids` is empty. Manual connections require remote
approval. Static IP configurations require both Azure subresource and member names.

All configurable defaults live in [variables.tf](variables.tf). The typed objects
are the complete input contract; [outputs.tf](outputs.tf) lists parent and keyed
child IDs and service connection metadata. No tenant/subscription IDs or credentials
are output. Keep stable map keys for stable Terraform addresses.

Validated against the released **AzureRM 4.81.0** documentation and schema (latest
4.x at review on 2026-11-08); constraint `>= 4.81, < 5.0`. Runtime Terraform requires
1.5 or later; native mocked tests require 1.7 or later (repository CI uses 1.9.8).

```sh
terraform init -backend=false
terraform fmt -check
terraform validate
terraform test
```

Tests use a mocked provider and never provision Azure resources. These checks do
not prove regional SKU availability, service quotas, real Entra authentication,
private DNS, connectivity or Azure create/update/delete behavior. Existing shared
CI initializes and validates every module; run the native tests above for behavior.

Resource references, pinned to the reviewed provider version:
- [`azurerm_eventhub_namespace`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/eventhub_namespace.html.markdown)
- [`azurerm_eventhub`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/eventhub.html.markdown)
- [`azurerm_eventhub_consumer_group`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/eventhub_consumer_group.html.markdown)
- [`azurerm_private_endpoint`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/private_endpoint.html.markdown)
- [`azurerm_role_assignment`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/role_assignment.html.markdown)
