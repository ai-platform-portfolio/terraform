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
  default     = null
}

variable "principal_id" {
  description = "Authorized existing managed identity object ID."
  type        = string
  sensitive   = true
  default     = null
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
  default     = null
}

variable "subject" {
  description = "Optional exact native OIDC subject, e.g. one Kubernetes ServiceAccount. Null preserves the Entra claims contract."
  type        = string
  default     = null

  validation {
    condition     = var.subject == null || can(regex("^system:serviceaccount:[a-z0-9-]+:[a-z0-9-]+$", var.subject))
    error_message = "Native AKS federation requires one exact ServiceAccount subject, never a wildcard."
  }
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
