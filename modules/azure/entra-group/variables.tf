variable "display_name" {
  description = "Display name for the Entra security group. Existing groups with this name must be imported rather than duplicated."
  type        = string
}

variable "description" {
  description = "Purpose of the Entra security group."
  type        = string
}

variable "owners" {
  description = "Object IDs of users or service principals that own the group. Include the Terraform principal when its permissions depend on group ownership."
  type        = set(string)

  validation {
    condition     = length(var.owners) > 0
    error_message = "Specify at least one group owner."
  }
}

variable "members" {
  description = "Complete set of member object IDs. Ownership alone does not make a principal a member."
  type        = set(string)
}

variable "role_assignments" {
  description = "Scoped Azure roles granted to this group, keyed by purpose. These are Azure RBAC assignments, not Entra directory roles."
  type = map(object({
    scope                = string
    role_definition_name = string
  }))
  default = {}
}
