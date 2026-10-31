variable "schema_dir" {
  type    = string
  default = "schema43"
}

variable "role_names" {
  type    = list(string)
  default = ["preview_pr43_owner", "preview_pr43_migrator", "preview_pr43_app"]
}

variable "test_prefix" {
  type    = string
  default = "preview_pr43"
}
