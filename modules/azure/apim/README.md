# Private API Management

Creates a Standard v2 API Management instance in an existing resource group,
using a caller-supplied managed identity, outbound VNet integration and an inbound
gateway private endpoint. APIs, policies and backend permissions are caller-owned.

## Network contract

The integration subnet must be dedicated, /27 or larger, delegated to
`Microsoft.Web/serverFarms`, and in the same region/subscription as APIM. Its NSG
must allow the required Azure Key Vault dependency and caller-selected backends.
The caller must complete subnet/NSG configuration before passing its ID.

The private endpoint uses a separate undelegated subnet and an existing
`privatelink.azure-api.net` zone linked to the client networks. Only the gateway
supports this private endpoint; the module does not expose the developer portal
privately or establish connectivity between networks.

Azure requires creating the private endpoint before disabling public access.
The module creates the service, creates its endpoint, then uses AzAPI to set
`publicNetworkAccess` to `Disabled`. AzureRM ignores only that property; AzAPI
owns its final value. Ready service ID/URL outputs wait for this update. A failed
apply may leave public access enabled until the final update succeeds. The module
creates no APIs or API policies.

## Caller inputs

Required: `name`, `resource_group_name`, `location`, `sku_name`, `publisher_name`,
`publisher_email`, `managed_identity_id`, `integration_subnet_id`,
`private_endpoint_subnet_id` and `private_dns_zone_id`. Tags and operation timeouts
are optional. Supported SKUs are `StandardV2_1` through `StandardV2_10`; other tiers
have different networking contracts. Create/update/delete timeouts default to
three hours and can be overridden independently.

Callers own region/capacity selection, publisher metadata, identity lifecycle,
networking, backend roles and deployment state. No cloud credentials or runtime
secrets are accepted as inputs. Outputs provide the ready service ID/URL and
private endpoint ID.

## Validation

Run `terraform init -backend=false`, `terraform validate` and `terraform test`
with Terraform 1.9+. Mocked tests cover identity/network wiring, unsupported tiers,
subnet isolation and timeout overrides. Live capacity, connectivity and service
readiness require caller-side validation.

[Standard v2 VNet requirements](https://learn.microsoft.com/en-us/azure/api-management/integrate-vnet-outbound).
[Private endpoint requirements](https://learn.microsoft.com/en-us/azure/api-management/private-endpoint).
