atlas {
  cloud {
    org = "ai-platform-portfolio"
  }
}

variable "passwords" {
  type = map(string)
  default = {
    migrator = getenv("ATLAS_MIGRATOR_PASSWORD")
    runtime  = getenv("ATLAS_RUNTIME_PASSWORD")
  }
}

env "roles" {
  test {
    schema {
      src  = ["roles.test.hcl"]
      vars = { prefix = var.test_prefix }
    }
  }
}
