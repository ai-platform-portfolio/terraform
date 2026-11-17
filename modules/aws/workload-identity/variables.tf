variable "name" {
  description = "Stable role name supplied by the foundation caller."
  type        = string
}

variable "trust" {
  description = "Exact Kubernetes OIDC issuer, audience and ServiceAccount subject."
  type = object({
    issuer   = string
    audience = string
    subject  = string
  })

  validation {
    condition     = startswith(var.trust.issuer, "https://") && length(var.trust.audience) > 0 && can(regex("^system:serviceaccount:[a-z0-9.-]+:[a-z0-9.-]+$", var.trust.subject))
    error_message = "Declare an HTTPS issuer, nonempty audience and exact Kubernetes ServiceAccount subject."
  }
}

variable "policy" {
  description = "Native IAM permission policy JSON; the caller owns service/resource scope."
  type        = string

  validation {
    condition     = can(jsondecode(var.policy).Statement)
    error_message = "Supply a native IAM policy document with explicit Statements."
  }
}
