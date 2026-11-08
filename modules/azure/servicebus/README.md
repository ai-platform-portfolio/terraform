# servicebus

Creates one Service Bus namespace. Parent repetition belongs to the caller's
module `for_each`; this module never loops its parent resource. Provide an
existing resource group and region. It owns no provider configuration or state.

```hcl
module "service" {
  source = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/servicebus?ref=<full-commit-sha>"

  name                = var.service_name
  resource_group_name = var.resource_group_name
  location            = var.location

  queues = { jobs = {} }
  topics = { events = {} }
  subscriptions = { worker = { topic_key = "events" } }
  subscription_rules = {
    selected = {
      subscription_key = "worker"
      filter_type      = "SqlFilter"
      sql_filter       = "kind = 'order'"
    }
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

Queues, topics, topic subscriptions, SQL/correlation rules, parent-scoped Azure
RBAC and private endpoints are keyed maps. Subscriptions use `topic_key`; rules
use `subscription_key`. Names default to map keys, so keep keys stable.

Premium is the default (`capacity = 1`, `premium_messaging_partitions = 1`) and is
required for private endpoints/firewall rules. For Standard or Basic, explicitly
set both values to `0` and enable public access if clients need connectivity;
Basic cannot host topics. Premium partitioning is configured at namespace
creation, not on individual queues/topics. Do not enable express entities on
Premium. SKU/partition/entity-property changes can require replacement.

Azure creates a catch-all `$Default` subscription rule. For filtered subscriptions,
configure the caller's provider to remove that rule on creation:

```hcl
provider "azurerm" {
  features {
    servicebus {
      auto_delete_subscription_default_rule = true
    }
  }
}
```

This native AzureRM 4.81 feature applies to newly created subscriptions using that
provider configuration. It does not remove catch-all rules from existing
subscriptions. Naming a new Terraform rule `$Default` without removal/import fails
the provider's existing-resource check; adding a separately named filter without
removal leaves the catch-all active. Existing resources require a deliberate
adoption plan in the caller.

Forwarding names must identify existing destinations; forwarding between newly
created entities in the same map has no explicit dependency ordering in this
module.

SAS authorization rules and connection-string outputs are intentionally omitted.
Entra applications use caller-selected Service Bus data roles. Parent-scoped RBAC
applies across the namespace; callers can assign narrower roles outside this module
using the exported child IDs. No application identities are created.

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
- [`azurerm_servicebus_namespace`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/servicebus_namespace.html.markdown)
- [`azurerm_servicebus_queue`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/servicebus_queue.html.markdown)
- [`azurerm_servicebus_topic`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/servicebus_topic.html.markdown)
- [`azurerm_servicebus_subscription`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/servicebus_subscription.html.markdown)
- [`azurerm_servicebus_subscription_rule`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/servicebus_subscription_rule.html.markdown)
- [`azurerm_private_endpoint`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/private_endpoint.html.markdown)
- [`azurerm_role_assignment`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/role_assignment.html.markdown)
- [AzureRM provider Service Bus feature](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/guides/features-block.html.markdown)
