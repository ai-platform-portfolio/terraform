variable "project_id" {
  description = "Existing Google project."
  type        = string
  sensitive   = true
}

variable "pool_id" {
  description = "Existing workload identity pool ID; this module never adopts the pool."
  type        = string
}

variable "provider_id" {
  description = "Unique provider ID within the existing pool."
  type        = string
}

variable "service_account_email" {
  description = "Existing service account whose permissions the exact subject may use."
  type        = string
  sensitive   = true
}

variable "trust" {
  description = "Exact Kubernetes issuer, dedicated token audience and ServiceAccount subject."
  type = object({
    issuer   = string
    audience = string
    subject  = string
  })

  validation {
    condition     = startswith(var.trust.issuer, "https://") && length(var.trust.audience) > 0 && can(regex("^system:serviceaccount:[a-z0-9.-]+:[a-z0-9.-]+$", var.trust.subject))
    error_message = "Declare an HTTPS issuer, dedicated audience and exact Kubernetes ServiceAccount subject."
  }
}
