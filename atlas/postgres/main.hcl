env "roles" {
  # Atlas accepts a set of keys here, rather than a map of objects directly.
  for_each = toset([for key in keys(var.targets) : key if var.target == "" || var.target == key])

  url = var.role_url
  dev = var.dev_url

  # Matching schema variables are bound natively, without generating HCL.
  passwords = var.targets[each.value].passwords

  # PostgreSQL roles are instance-wide. Each target has its own exact scope.
  include = [for name in var.targets[each.value].role_names : "${name}[type=role|user]"]

  schema {
    src = "file://${var.targets[each.value].schema_dir}"

    mode {
      schemas     = false
      objects     = false
      roles       = true
      permissions = false
      sensitive   = ALLOW
    }
  }
}
