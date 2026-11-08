# managed-redis

Creates one Azure Managed Redis instance. Parent repetition belongs to the caller's
module `for_each`; this module never loops its parent resource. Provide an
existing resource group and region. It owns no provider configuration or state.

```hcl
module "service" {
  source = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/managed-redis?ref=<full-commit-sha>"

  name                = var.service_name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku_name = var.redis.sku_name
  default_database = { modules = { RedisJSON = {} } }
  access_policy_assignments = {
    worker = { object_id = var.worker_principal_id }
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

Creates the single supported `default_database` inline with the instance. Redis
modules (for example RedisJSON), Entra access assignments and private endpoints
use maps; the database itself is not looped. The caller must supply a current
Managed Redis `sku_name`, for example `Balanced_B0`. Legacy Enterprise SKUs and
Azure Cache for Redis resources are not used.

Defaults disable public access, access-key authentication and high availability;
clients must use encrypted connections and Entra tokens. Enable high availability
explicitly when a replica is required. Database defaults are OSSCluster and
VolatileLRU. Access assignments accept Entra object IDs. AzureRM 4.81 exposes no
custom Redis ACL/policy argument: do not interpret an assignment as a restricted
per-key or per-command policy. Azure management-plane RBAC is distinct from Redis
data access and belongs in the caller.

Choose at most one persistence mode. Persistence cannot be combined with
geo-replication. `geo_replication_group_name` creates the initial group; cross-instance
membership is not managed here. Changing clustering policy, Redis module settings
or geo-replication group can recreate the database and lose data; SKU and HA changes
can also replace resources. Review real consumer plans before applying.

This module uses `azurerm_managed_redis`, not retiring classic Cache for Redis or
deprecated Redis Enterprise resources. It does not output access keys.

Private endpoints default to subresource `redisEnterprise`. Use existing DNS zone
`privatelink.redis.azure.net` and link it to client VNets in the caller. DNS zone
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
- [`azurerm_managed_redis`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/managed_redis.html.markdown)
- [`azurerm_managed_redis_access_policy_assignment`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/managed_redis_access_policy_assignment.html.markdown)
- [`azurerm_private_endpoint`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.81.0/website/docs/r/private_endpoint.html.markdown)
- [Microsoft: Azure Cache for Redis retirement](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/retirement-faq)
