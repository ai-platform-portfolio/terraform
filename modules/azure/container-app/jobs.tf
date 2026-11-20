# Related scheduled commands share this application's image and permanent identity.
resource "azurerm_container_app_job" "this" {
  for_each = var.scheduled_jobs

  name                         = "${var.name}-${each.key}"
  location                     = azurerm_container_app.this.location
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  workload_profile_name        = "Consumption"
  replica_timeout_in_seconds   = each.value.timeout_seconds
  replica_retry_limit          = each.value.retry_limit

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

  schedule_trigger_config {
    cron_expression          = each.value.schedule
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name    = "${var.name}-${each.key}"
      image   = var.image
      cpu     = var.cpu
      memory  = var.memory
      command = each.value.command
      args    = each.value.args

      dynamic "env" {
        for_each = each.value.environment_variables

        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  tags = var.tags
}
