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
