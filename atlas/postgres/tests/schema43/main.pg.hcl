# Atlas takes role names from literal block labels; `name` does not override them.
role "preview_pr43_owner" {
  superuser   = false
  create_db   = false
  create_role = false
}

user "preview_pr43_migrator" {
  password    = var.passwords["migrator"]
  member_of   = [role.preview_pr43_owner]
  superuser   = false
  create_db   = false
  create_role = false
}

user "preview_pr43_app" {
  password    = var.passwords["runtime"]
  superuser   = false
  create_db   = false
  create_role = false
}
