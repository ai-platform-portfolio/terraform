terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Hubless Fleet groups existing clusters for inventory and update orchestration.
# Argo remains the only owner of application placement and reconciliation.
resource "azurerm_kubernetes_fleet_manager" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
