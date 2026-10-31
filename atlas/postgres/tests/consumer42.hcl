variable "schema_dir" {
  type    = string
  default = "schema42"
}

variable "role_names" {
  type    = list(string)
  default = ["preview_pr42_owner", "preview_pr42_migrator", "preview_pr42_app"]
}

variable "test_prefix" {
  type    = string
  default = "preview_pr42"
}
