mock_provider "azurerm" {
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      kube_config = [{ host = "https://example.invalid", cluster_ca_certificate = "ZmFrZS1jYQ==", client_certificate = "", client_key = "", password = "", username = "" }]
    }
  }

  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-example/providers/Microsoft.ManagedIdentity/userAssignedIdentities/control-plane"
    }
  }
}

variables {
  name                   = "aks-example"
  location               = "uksouth"
  resource_group_name    = "rg-example"
  tenant_id              = "00000000-0000-0000-0000-000000000001"
  kubernetes_version     = "1.35.0"
  vnet_subnet_id         = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/rg-example/providers/Microsoft.Network/virtualNetworks/example/subnets/system"
  admin_group_object_ids = ["00000000-0000-0000-0000-000000000003"]
  authorized_ip_ranges   = ["192.0.2.1/32"]
}

run "existing_callers" {
  command = plan

  assert {
    condition     = !azurerm_kubernetes_cluster.this.storage_profile[0].blob_driver_enabled
    error_message = "Existing callers must not enable Blob CSI implicitly."
  }
}

run "native_blob" {
  command = plan

  variables { blob_driver_enabled = true }

  assert {
    condition     = azurerm_kubernetes_cluster.this.storage_profile[0].blob_driver_enabled && azurerm_kubernetes_cluster.this.storage_profile[0].disk_driver_enabled != false && azurerm_kubernetes_cluster.this.storage_profile[0].file_driver_enabled != false
    error_message = "Enable Blob CSI without disabling the native Disk/File drivers."
  }
}
