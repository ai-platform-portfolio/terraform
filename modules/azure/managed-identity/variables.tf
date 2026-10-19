variable "name" {
  description = "Managed identity name."
  type        = string
}
variable "resource_group_name" {
  description = "Existing resource group."
  type        = string
}
variable "location" {
  description = "Azure region."
  type        = string
}
variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
variable "federated_credentials" {
  description = "OIDC credentials keyed by name."
  type = map(object({
    issuer    = string
    subject   = string
    audiences = optional(list(string), ["api://AzureADTokenExchange"])
  }))
  default = {}
}

variable "role_assignments" {
  description = "Scoped Azure roles granted to this identity, keyed by purpose."
  type = map(object({
    scope                = string
    role_definition_name = string
  }))
  default = {}
}

variable "principal_type" {
  description = "Azure principal type used for managed identity role assignments."
  type        = string
  default     = "ServicePrincipal"
}
