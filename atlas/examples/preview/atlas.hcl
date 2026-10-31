# Load after ../../postgres/atlas.hcl. Paths are relative to this directory.
atlas {
  cloud {
    org = "ai-platform-portfolio"
  }
}

# Keep these exact names aligned with the literal labels in roles.pg.hcl.
variable "role_names" {
  type    = list(string)
  default = ["preview_pr42_owner", "preview_pr42_migrator", "preview_pr42_app"]
}

env "roles" {
  test {
    schema {
      src = ["tests/roles.test.hcl"]
    }
  }
}
