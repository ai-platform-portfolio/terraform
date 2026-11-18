variable "instance_arn" {
  description = "Existing IAM Identity Center instance in the provider's region."
  type        = string
}

variable "name" {
  description = "Permission set name, also used to select the role in the CLI profile."
  type        = string
}

variable "description" {
  description = "Purpose of this permission set."
  type        = string
}

variable "account_id" {
  description = "One target AWS account; the caller owns repetition across accounts."
  type        = string
}

variable "session_duration" {
  description = "AWS role credential lifetime, not the interactive SSO sign-in lifetime."
  type        = string
  default     = "PT1H"

  validation {
    condition     = contains([for hours in range(1, 13) : "PT${hours}H"], var.session_duration)
    error_message = "Choose a whole-hour role duration from PT1H through PT12H."
  }
}

variable "policy" {
  description = "Native IAM permission document; the caller supplies resource scope."
  type        = string

  validation {
    condition     = can(jsondecode(var.policy).Statement)
    error_message = "Supply a native IAM policy with explicit Statements."
  }
}

variable "principals" {
  description = "Already provisioned Identity Store users/groups keyed by stable caller identity."
  type = map(object({
    id   = string
    type = string
  }))

  validation {
    condition     = alltrue([for principal in var.principals : contains(["USER", "GROUP"], principal.type)])
    error_message = "Principals must be Identity Store USER or GROUP identities."
  }
}
