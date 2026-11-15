terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81, < 5.0"
    }
  }
}

locals {
  domains = var.custom_domain == null ? {} : { this = var.custom_domain }
}

resource "azurerm_container_app" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  workload_profile_name        = "Consumption"
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  dynamic "registry" {
    for_each = var.registry_server == null ? [] : [var.registry_server]

    content {
      server   = registry.value
      identity = var.managed_identity_id
    }
  }

  ingress {
    external_enabled           = var.external_ingress_enabled
    allow_insecure_connections = false
    target_port                = var.target_port
    transport                  = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.replicas.min
    max_replicas = var.replicas.max

    container {
      name   = "web"
      image  = var.image
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = var.environment_variables

        content {
          name  = env.key
          value = env.value
        }
      }

      liveness_probe {
        transport        = "HTTP"
        port             = var.target_port
        path             = var.health_probe_path
        interval_seconds = 30
      }

      readiness_probe {
        transport = "HTTP"
        port      = var.target_port
        path      = var.health_probe_path
      }
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.custom_domain == null || var.external_ingress_enabled
      error_message = "Managed custom-domain HTTPS requires public ingress."
    }
  }
}

resource "azurerm_dns_cname_record" "this" {
  for_each = local.domains

  name                = trimsuffix(each.value.hostname, ".${each.value.zone_name}")
  zone_name           = each.value.zone_name
  resource_group_name = each.value.resource_group_name
  ttl                 = 300
  record              = azurerm_container_app.this.ingress[0].fqdn
}

resource "azurerm_dns_txt_record" "this" {
  for_each = local.domains

  name                = "asuid.${trimsuffix(each.value.hostname, ".${each.value.zone_name}")}"
  zone_name           = each.value.zone_name
  resource_group_name = each.value.resource_group_name
  ttl                 = 300

  record {
    value = azurerm_container_app.this.custom_domain_verification_id
  }
}

resource "azurerm_container_app_custom_domain" "this" {
  for_each = local.domains

  name             = each.value.hostname
  container_app_id = azurerm_container_app.this.id

  # The AzAPI resource below owns only the managed-certificate binding.
  lifecycle {
    ignore_changes = [certificate_binding_type, container_app_environment_certificate_id]
  }

  depends_on = [azurerm_dns_cname_record.this, azurerm_dns_txt_record.this]
}

resource "azurerm_container_app_environment_managed_certificate" "this" {
  for_each = local.domains

  name                         = "${var.name}-https"
  container_app_environment_id = var.container_app_environment_id
  subject_name                 = each.value.hostname
  domain_control_validation    = "CNAME"

  depends_on = [azurerm_container_app_custom_domain.this]
}

# Remove the binding before deleting its certificate during host destruction.
# azapi_update_resource alone leaves its patched properties behind on destroy.
resource "azapi_resource_action" "unbind_https" {
  for_each = local.domains

  type                   = "Microsoft.App/containerApps@2025-07-01"
  resource_id            = azurerm_container_app.this.id
  method                 = "PATCH"
  when                   = "destroy"
  ignore_not_found       = true
  response_export_values = []

  body = {
    properties = {
      configuration = {
        ingress = { customDomains = [] }
      }
    }
  }

  lifecycle {
    replace_triggered_by = [azurerm_container_app_environment_managed_certificate.this[each.key]]
  }

  depends_on = [azurerm_container_app_environment_managed_certificate.this]
}

resource "azapi_update_resource" "https_binding" {
  for_each = local.domains

  type                   = "Microsoft.App/containerApps@2025-07-01"
  resource_id            = azurerm_container_app.this.id
  response_export_values = []

  body = {
    properties = {
      configuration = {
        ingress = {
          customDomains = [{
            name          = each.value.hostname
            bindingType   = "SniEnabled"
            certificateId = azurerm_container_app_environment_managed_certificate.this[each.key].id
          }]
        }
      }
    }
  }

  depends_on = [azapi_resource_action.unbind_https]
}
