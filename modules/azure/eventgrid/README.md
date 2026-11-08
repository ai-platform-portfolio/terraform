# eventgrid

Creates one Event Grid domain. Parent repetition belongs to the caller's
module `for_each`; this module never loops its parent resource. Provide an
existing resource group and region. It owns no provider configuration or state.

```hcl
module "service" {
  source = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/eventgrid?ref=<full-commit-sha>"

  name                = var.service_name
  resource_group_name = var.resource_group_name
  location            = var.location

  topics = { orders = {} }
  event_subscriptions = {
    processor = {
      topic_key                     = "orders"
      service_bus_queue_endpoint_id = var.queue_id
      delivery_identity = {
        type                   = "UserAssigned"
        user_assigned_identity = var.delivery_identity_id
      }
    }
  }
  identity = {
    type         = "UserAssigned"
    identity_ids = [var.delivery_identity_id]
  }

  private_endpoints = {
    workload = {
      subnet_id            = var.endpoint_subnet_id
      private_dns_zone_ids = [var.private_dns_zone_id]
    }
  }

  tags = var.tags
}
```

Domain topics, event subscriptions, parent-scoped Azure RBAC and private endpoints
use keyed maps. An event subscription uses `topic_key` for a declared domain topic;
omitting it subscribes at domain scope. Names default to map keys. Azure's implicit
topic creation/deletion settings default to false so subscription removal cannot
delete a separately managed topic.

Each subscription requires exactly one destination: Event Hub, Service Bus queue
or topic, hybrid connection, Storage Queue, Azure Function or webhook. Supported
settings include event types, subject/advanced filters, delivery/dead-letter
identities, blob dead-letter destinations and retry policy. Retry defaults are
30 attempts and 1,440 minutes. Webhook delivery can use Entra tenant/application
settings; endpoint validation and receiver authorization remain prerequisites.
Do not put credentials in webhook URLs.

Private endpoints secure **publishing ingress**. They do not provide private
outbound push delivery to subscribers. Configure supported destination networking,
trusted-service access and data-plane permissions separately. Managed delivery
identities must be enabled on the domain and granted access to destinations before
subscriptions are created. Use caller-owned user-assigned identities when needed
to avoid dependency cycles. No receiver, storage or delivery permission is created.

This module implements the domain/topic model. Event Grid namespaces/MQTT, system
topics and standalone custom topics are different parent resource models and are
not created. Shared-key outputs are omitted. Exported topic IDs allow narrower
caller-managed RBAC; module RBAC is scoped to the domain.

Private endpoints default to subresource `domain`. Use existing DNS zone
`privatelink.eventgrid.azure.net` and link it to client VNets in the caller. DNS zone
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
- [`azurerm_eventgrid_domain`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/eventgrid_domain.html.markdown)
- [`azurerm_eventgrid_domain_topic`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/eventgrid_domain_topic.html.markdown)
- [`azurerm_eventgrid_event_subscription`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/eventgrid_event_subscription.html.markdown)
- [`azurerm_private_endpoint`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/private_endpoint.html.markdown)
- [`azurerm_role_assignment`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/role_assignment.html.markdown)
- [Microsoft: Event Grid private endpoints](https://learn.microsoft.com/en-us/azure/event-grid/configure-private-endpoints)
