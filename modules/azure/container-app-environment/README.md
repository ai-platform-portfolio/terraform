# Container Apps environment

One Azure Container Apps environment with the Consumption workload profile. The
caller owns the resource group, provider configuration and repetition. No dedicated
profile, VNet, gateway or Log Analytics workspace is provisioned.

Required inputs: `name`, `resource_group_name`, `location`. `tags` defaults to an
empty map. Outputs: `id`, `default_domain`.

```hcl
module "environment" {
  source              = "git::https://github.com/ai-platform-portfolio/terraform.git//modules/azure/container-app-environment?ref=<full-commit-sha>"
  name                = var.environment.name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.azure.location
}
```

Applications consume `module.environment.id`. Use a caller-owned `for_each` when
creating multiple environments. This module has no deployment backend and does
not configure application identities or register applications in GitOps.
