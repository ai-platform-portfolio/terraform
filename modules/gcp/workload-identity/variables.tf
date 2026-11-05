variable "project_id" {
  description = "Existing Google project supplied externally."
  type        = string
  sensitive   = true
}

variable "name" {
  description = "Name for the service account and prefix for the workload identity pool."
  type        = string
}

variable "tenant_id" {
  description = "Authorized Entra tenant."
  type        = string
  sensitive   = true
}

variable "principal_id" {
  description = "Authorized existing managed identity object ID."
  type        = string
  sensitive   = true
}

variable "issuer" {
  description = "Exact issuer of the trusted Entra token."
  type        = string
  sensitive   = true
}

variable "audience" {
  description = "Dedicated Entra application ID URI for Google federation."
  type        = string
  sensitive   = true
}

variable "role_value" {
  description = "Required application role claim."
  type        = string
}

variable "provider_id" {
  description = "Stable runtime provider ID."
  type        = string
  default     = "azure"
}

variable "role" {
  description = "Caller-defined project role granted to the federated service account."
  type = object({
    id          = string
    title       = string
    description = string
    permissions = set(string)
  })
}
