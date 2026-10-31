# Load for schema lint in CI, separately from password-bearing schema apply.
variable "policy_file" {
  type = string
}

env "roles" {
  lint {
    rule "hcl" "application-roles" {
      error = true
      src = [var.policy_file]
    }
  }
}
