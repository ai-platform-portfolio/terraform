predicate "role" "non_administrative" {
  superuser { eq = false }
  create_db { eq = false }
  create_role { eq = false }
  replication { eq = false }
  bypass_rls { eq = false }
}

predicate "user" "non_administrative" {
  superuser { eq = false }
  create_db { eq = false }
  create_role { eq = false }
  replication { eq = false }
  bypass_rls { eq = false }
}

rule "schema" "application-roles-no-admin" {
  description = "Application roles and users must not have administrative privileges"

  role {
    assert {
      predicate = predicate.role.non_administrative
      message = "role ${self.name} must not have administrative privileges"
    }
  }

  user {
    assert {
      predicate = predicate.user.non_administrative
      message = "user ${self.name} must not have administrative privileges"
    }
  }
}
