env "roles" {
  url = var.role_url
  dev = var.dev_url

  passwords = var.passwords

  # PostgreSQL roles are instance-wide; the caller supplies its exact scope.
  include = [for name in var.role_names : "${name}[type=role|user]"]

  schema {
    src = "file://${var.schema_dir}"

    mode {
      schemas     = false
      objects     = false
      roles       = true
      permissions = false
      sensitive   = ALLOW
    }
  }
}
