output "id" {
  description = "Foundry account resource ID."
  value       = azapi_resource.account.id
}

output "openai_endpoint" {
  description = "OpenAI-compatible endpoint; resolve through the private endpoint and authenticate with Entra."
  value       = "https://${coalesce(var.account_settings.custom_subdomain_name, var.name)}.openai.azure.com/"
}

output "private_endpoint_id" {
  description = "Private endpoint connected to the Foundry account."
  value       = azapi_resource.private_endpoint.id
}

output "deployments" {
  description = "Model deployment names and IDs for subsequent gateway routing."
  value = {
    for key, deployment in azurerm_cognitive_deployment.this : key => {
      id   = deployment.id
      name = deployment.name
    }
  }
}

output "projects" {
  description = "Foundry project IDs and service endpoints."
  value = {
    for key, project in azurerm_cognitive_account_project.this : key => {
      id        = project.id
      endpoints = project.endpoints
    }
  }
}
