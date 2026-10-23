terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "${var.name}-control-plane"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "network" {
  for_each             = merge({ system = var.vnet_subnet_id }, { for name, pool in var.user_node_pools : "user-${name}" => pool.vnet_subnet_id })
  scope                = each.value
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_kubernetes_cluster" "this" {
  name                              = var.name
  location                          = var.location
  resource_group_name               = var.resource_group_name
  dns_prefix                        = var.name
  kubernetes_version                = var.kubernetes_version
  sku_tier                          = var.sku_tier
  local_account_disabled            = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  private_cluster_enabled           = var.private_cluster_enabled
  role_based_access_control_enabled = true
  tags                              = var.tags

  default_node_pool {
    name                         = "system"
    temporary_name_for_rotation  = "systemtemp"
    vm_size                      = var.system_node_pool.vm_size
    node_count                   = var.system_node_pool.node_count
    vnet_subnet_id               = var.vnet_subnet_id
    max_pods                     = var.max_pods
    os_disk_size_gb              = var.system_node_pool.os_disk_size_gb
    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "1"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = var.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = false
  }

  api_server_access_profile {
    authorized_ip_ranges = var.authorized_ip_ranges
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  depends_on = [azurerm_role_assignment.network]
}

resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each              = var.user_node_pools
  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  vnet_subnet_id        = each.value.vnet_subnet_id
  max_pods              = var.max_pods
  os_disk_size_gb       = each.value.os_disk_size_gb
  mode                  = "User"
  tags                  = var.tags

  upgrade_settings {
    max_surge = "1"
  }
}
