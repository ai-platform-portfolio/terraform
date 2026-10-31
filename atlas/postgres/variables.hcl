variable "schema_dir" {
  description = "Caller-owned directory containing related role/user resources and schema inputs."
  type        = string
}

variable "role_names" {
  description = "Exact role names owned by this caller."
  type        = list(string)

  validation {
    condition = length(var.role_names) > 0 && alltrue([
      for name in var.role_names : length(regexall("^[a-z][a-z0-9_]{0,62}$", name)) == 1
    ])
    error_message = "Provide at least one exact role name: lowercase letters, numbers and underscores, starting with a letter, at most 63 characters."
  }
}

variable "passwords" {
  description = "Secret-delivered login passwords keyed as referenced by the caller's schema."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for password in values(var.passwords) : password != ""])
    error_message = "Password entries must have nonempty secret values."
  }
}

variable "policy_file" {
  description = "Path to the shared policy when loading lint.hcl for schema lint."
  type        = string
  default     = ""
}

variable "role_url" {
  description = "Direct PostgreSQL connection for the role manager, supplied by secret delivery."
  type        = string
  default     = getenv("ATLAS_ROLE_URL")
}

variable "dev_url" {
  description = "Dedicated disposable instance for validation/lint/tests; unset for role apply."
  type        = string
  default     = getenv("ATLAS_DEV_URL")
}
