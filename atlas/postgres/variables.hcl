variable "targets" {
  description = "Role sets keyed by application/environment; each owns its exact role names."
  type = map(object({
    schema_dir = string
    role_names = list(string)
    passwords  = map(string)
  }))

  validation {
    condition = length(var.targets) > 0 && alltrue([
      for target in values(var.targets) :
      target.schema_dir != "" && length(target.role_names) > 0 && alltrue([
        for name in target.role_names : length(regexall("^[a-z][a-z0-9_]{0,62}$", name)) == 1
      ]) && alltrue([for password in values(target.passwords) : password != ""])
    ])
    error_message = "Provide targets with schema directories, nonempty secret values and exact role names: lowercase letters, numbers and underscores, starting with a letter, at most 63 characters."
  }
}

variable "target" {
  description = "Select one target for validate/lint/test or scoped apply; empty applies all targets."
  type        = string
  default     = ""

  validation {
    condition     = var.target == "" || contains(keys(var.targets), var.target)
    error_message = "The selected target must exist in targets."
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
