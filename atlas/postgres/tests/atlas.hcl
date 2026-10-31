atlas {
  cloud {
    org = "ai-platform-portfolio"
  }
}

# Two consumers on one server exercise the library's native target loop.
variable "targets" {
  type = map(object({
    schema_dir = string
    role_names = list(string)
    passwords  = map(string)
  }))

  default = {
    preview_pr42 = {
      schema_dir = "schema42"
      role_names = ["preview_pr42_owner", "preview_pr42_migrator", "preview_pr42_app"]
      passwords = {
        migrator = getenv("ATLAS_MIGRATOR_PASSWORD")
        runtime  = getenv("ATLAS_RUNTIME_PASSWORD")
      }
    }

    preview_pr43 = {
      schema_dir = "schema43"
      role_names = ["preview_pr43_owner", "preview_pr43_migrator", "preview_pr43_app"]
      passwords = {
        migrator = getenv("ATLAS_MIGRATOR_PASSWORD")
        runtime  = getenv("ATLAS_RUNTIME_PASSWORD")
      }
    }
  }
}

env "roles" {
  test {
    schema {
      src = ["roles.test.hcl"]
      vars = { prefix = each.value }
    }
  }
}
