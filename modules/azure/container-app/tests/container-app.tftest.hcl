mock_provider "azurerm" {
  mock_resource "azurerm_container_app" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example/providers/Microsoft.App/containerApps/example"
    }
  }

  mock_resource "azurerm_container_app_environment_managed_certificate" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example/providers/Microsoft.App/managedEnvironments/example/managedCertificates/example-https"
    }
  }
}

mock_provider "azapi" {}

variables {
  name                         = "example"
  resource_group_name          = "example"
  container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example/providers/Microsoft.App/managedEnvironments/example"
  managed_identity_id          = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/example/providers/Microsoft.ManagedIdentity/userAssignedIdentities/example"
  image                        = "example.azurecr.io/web@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}

run "private_defaults_without_domain_or_registry" {
  command = plan

  assert {
    condition = (
      !azurerm_container_app.this.ingress[0].external_enabled &&
      !azurerm_container_app.this.ingress[0].allow_insecure_connections &&
      azurerm_container_app.this.template[0].min_replicas == 0 &&
      azurerm_container_app.this.template[0].max_replicas == 1 &&
      length(azurerm_container_app.this.registry) == 0 &&
      length(azurerm_dns_cname_record.this) == 0 &&
      length(azurerm_container_app_environment_managed_certificate.this) == 0 &&
      length(azapi_update_resource.https_binding) == 0 &&
      length(azapi_resource_action.unbind_https) == 0
    )
    error_message = "Default intent must not expose the app or allocate domain/certificate resources."
  }
}

run "public_https_and_ordered_cleanup" {
  command = apply

  variables {
    external_ingress_enabled = true
    registry_server          = "example.azurecr.io"
    replicas                 = { min = 1 }
    custom_domain = {
      hostname            = "api.example.com"
      zone_name           = "example.com"
      resource_group_name = "dns"
    }
  }

  assert {
    condition = (
      azurerm_dns_cname_record.this["this"].name == "api" &&
      azurerm_dns_txt_record.this["this"].name == "asuid.api" &&
      azapi_update_resource.https_binding["this"].body.properties.configuration.ingress.customDomains[0].certificateId == azurerm_container_app_environment_managed_certificate.this["this"].id &&
      azapi_resource_action.unbind_https["this"].resource_id == azurerm_container_app.this.id &&
      azapi_resource_action.unbind_https["this"].when == "destroy" &&
      azapi_resource_action.unbind_https["this"].method == "PATCH" &&
      azapi_resource_action.unbind_https["this"].ignore_not_found &&
      length(azapi_resource_action.unbind_https["this"].body.properties.configuration.ingress.customDomains) == 0 &&
      azurerm_container_app.this.registry[0].identity == var.managed_identity_id &&
      azurerm_container_app.this.template[0].min_replicas == 1
    )
    error_message = "HTTPS must use this app's managed certificate/identity and a scoped destroy-only unbind."
  }
}

run "another_consumer_controls_names" {
  command = plan

  variables {
    name                     = "another-service"
    external_ingress_enabled = true
    custom_domain = {
      hostname            = "second.apps.example.net"
      zone_name           = "example.net"
      resource_group_name = "another-dns"
    }
  }

  assert {
    condition = (
      azurerm_container_app.this.name == "another-service" &&
      azurerm_container_app_environment_managed_certificate.this["this"].name == "another-service-https" &&
      azurerm_dns_cname_record.this["this"].name == "second.apps" &&
      azurerm_dns_txt_record.this["this"].resource_group_name == "another-dns" &&
      output.url == "https://second.apps.example.net"
    )
    error_message = "Names, DNS ownership and URLs must follow the second caller's intent unchanged."
  }
}

run "reject_private_managed_hostname" {
  command = plan

  variables {
    custom_domain = {
      hostname            = "api.example.com"
      zone_name           = "example.com"
      resource_group_name = "dns"
    }
  }

  expect_failures = [azurerm_container_app.this]
}

run "reject_invalid_replica_bounds" {
  command = plan

  variables { replicas = { min = 2, max = 1 } }

  expect_failures = [var.replicas]
}
