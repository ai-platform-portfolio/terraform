
test "schema" "role_profile" {
  assert {
    sql           = <<-SQL
      SELECT count(*) = 3
         AND bool_and(NOT rolsuper AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolreplication AND NOT rolbypassrls)
      FROM pg_roles
      WHERE rolname IN ('preview_pr42_owner', 'preview_pr42_migrator', 'preview_pr42_app')
    SQL
    error_message = "The profile must contain exactly three roles without administrative privileges"
  }

  assert {
    sql           = <<-SQL
      SELECT NOT rolcanlogin
      FROM pg_roles
      WHERE rolname = 'preview_pr42_owner'
    SQL
    error_message = "The ownership role must not allow login"
  }

  assert {
    sql           = <<-SQL
      SELECT count(*) = 2 AND bool_and(rolcanlogin)
      FROM pg_roles
      WHERE rolname IN ('preview_pr42_migrator', 'preview_pr42_app')
    SQL
    error_message = "Only the migrator and runtime users should allow login"
  }

  assert {
    sql           = "SELECT pg_has_role('preview_pr42_migrator', 'preview_pr42_owner', 'MEMBER')"
    error_message = "The migration login needs membership of the ownership role"
  }

  assert {
    sql           = "SELECT NOT pg_has_role('preview_pr42_app', 'preview_pr42_owner', 'MEMBER')"
    error_message = "The application login must not inherit ownership rights"
  }
}
