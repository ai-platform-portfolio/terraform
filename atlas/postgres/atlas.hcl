variable "roles_file" {
  type    = string
  default = "roles.pg.hcl"
}

variable "role_names" {
  type = list(string)
  validation {
    condition = length(var.role_names) > 0 && alltrue([
      for name in var.role_names : length(regexall("^[a-z][a-z0-9_]{0,62}$", name)) == 1
    ])
    error_message = "Provide at least one exact role name: lowercase letters, numbers and underscores, starting with a letter, at most 63 characters."
  }
}

variable "role_url" {
  type    = string
  default = getenv("ATLAS_ROLE_URL")
}

variable "dev_url" {
  type    = string
  default = getenv("ATLAS_DEV_URL")
}

variable "migrator_password" {
  type    = string
  default = getenv("ATLAS_MIGRATOR_PASSWORD")

  validation {
    condition     = var.migrator_password != ""
    error_message = "Set ATLAS_MIGRATOR_PASSWORD through the secret delivery mechanism."
  }
}

variable "runtime_password" {
  type    = string
  default = getenv("ATLAS_RUNTIME_PASSWORD")

  validation {
    condition     = var.runtime_password != ""
    error_message = "Set ATLAS_RUNTIME_PASSWORD through the secret delivery mechanism."
  }
}

data "hcl_schema" "roles" {
  path = var.roles_file
  vars = {
    migrator_password = var.migrator_password
    runtime_password  = var.runtime_password
  }
}

env "roles" {
  url = var.role_url
  dev = var.dev_url

  # PostgreSQL roles are instance-wide. Exact names isolate each application.
  include = [for name in var.role_names : "${name}[type=role|user]"]

  schema {
    src = data.hcl_schema.roles.url
    mode {
      schemas     = false
      objects     = false
      roles       = true
      permissions = false
      sensitive   = ALLOW
    }
  }

}
