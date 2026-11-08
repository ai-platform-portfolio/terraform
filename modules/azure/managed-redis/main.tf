terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81, < 5.0"
    }
  }
}

resource "azurerm_managed_redis" "this" {
  name                      = var.name
  resource_group_name       = var.resource_group_name
  location                  = var.location
  tags                      = var.tags
  sku_name                  = var.sku_name
  high_availability_enabled = var.high_availability_enabled
  public_network_access     = var.public_network_access

  dynamic "identity" {
    for_each = var.identity == null ? [] : [var.identity]

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  default_database {
    access_keys_authentication_enabled            = var.default_database.access_keys_authentication_enabled
    client_protocol                               = var.default_database.client_protocol
    clustering_policy                             = var.default_database.clustering_policy
    eviction_policy                               = var.default_database.eviction_policy
    geo_replication_group_name                    = var.default_database.geo_replication_group_name
    persistence_append_only_file_backup_frequency = var.default_database.persistence_append_only_file_backup_frequency
    persistence_redis_database_backup_frequency   = var.default_database.persistence_redis_database_backup_frequency

    dynamic "module" {
      for_each = var.default_database.modules

      content {
        name = module.key
        args = module.value.args
      }
    }
  }

  lifecycle {
    precondition {
      condition = (
        var.default_database.persistence_append_only_file_backup_frequency == null || var.default_database.persistence_redis_database_backup_frequency == null
        ) && (
        var.default_database.geo_replication_group_name == null || (var.default_database.persistence_append_only_file_backup_frequency == null && var.default_database.persistence_redis_database_backup_frequency == null)
      )
      error_message = "Choose at most one persistence method; persistence cannot be combined with geo-replication."
    }
  }
}

resource "azurerm_private_endpoint" "this" {
  for_each = var.private_endpoints

  name                          = coalesce(each.value.name, "${var.name}-${each.key}")
  resource_group_name           = coalesce(each.value.resource_group_name, var.resource_group_name)
  location                      = coalesce(each.value.location, var.location)
  subnet_id                     = each.value.subnet_id
  custom_network_interface_name = each.value.custom_network_interface_name
  tags                          = merge(var.tags, each.value.tags)

  private_service_connection {
    name                           = coalesce(each.value.connection_name, each.value.name, "${var.name}-${each.key}")
    private_connection_resource_id = azurerm_managed_redis.this.id
    subresource_names              = each.value.subresource_names
    is_manual_connection           = each.value.is_manual_connection
    request_message                = each.value.request_message
  }

  dynamic "private_dns_zone_group" {
    for_each = length(each.value.private_dns_zone_ids) == 0 ? [] : [each.value]

    content {
      name                 = private_dns_zone_group.value.private_dns_zone_group_name
      private_dns_zone_ids = private_dns_zone_group.value.private_dns_zone_ids
    }
  }

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.key
      private_ip_address = ip_configuration.value.private_ip_address
      subresource_name   = ip_configuration.value.subresource_name
      member_name        = ip_configuration.value.member_name
    }
  }
}

resource "azurerm_managed_redis_access_policy_assignment" "this" {
  for_each = var.access_policy_assignments

  managed_redis_id = azurerm_managed_redis.this.id
  object_id        = each.value.object_id
}
