variable "display_name" {
  description = "Display name of the new SAML enterprise application."
  type        = string
}

variable "template_name" {
  description = "Exact Entra gallery template name; gallery defaults own the SAML claims."
  type        = string
}

variable "owners" {
  description = "Stable application/principal owner object IDs, including the foundation operator."
  type        = set(string)

  validation {
    condition     = length(var.owners) > 0
    error_message = "Specify at least one owner."
  }
}

variable "service_provider" {
  description = "Entity ID, assertion consumer URL and portal URL from the service provider."
  type = object({
    entity_id = string
    acs_url   = string
    start_url = string
  })

  validation {
    condition     = alltrue([for url in [var.service_provider.entity_id, var.service_provider.acs_url, var.service_provider.start_url] : startswith(url, "https://")])
    error_message = "SAML service provider endpoints must use HTTPS."
  }
}

variable "assignments" {
  description = "Explicit Entra users/groups and the gallery role display name to assign."
  type = map(object({
    principal_object_id = string
    role_name           = string
  }))
}
