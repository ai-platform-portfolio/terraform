variable "display_name" {
  description = "Entra application display name."
  type        = string
}

variable "description" {
  description = "Purpose of the application."
  type        = string
  default     = null
}

variable "owners" {
  description = "Object IDs owning the application and its service principal. Include the deploying identity for ownership-based authority."
  type        = set(string)

  validation {
    condition     = length(var.owners) > 0
    error_message = "Specify at least one application owner."
  }
}

variable "prevent_duplicate_names" {
  description = "Reject an existing application with the same display name instead of creating another."
  type        = bool
  default     = true
}

variable "sign_in_audience" {
  description = "Microsoft account types allowed to authenticate. Personal accounts also require API access token version 2."
  type        = string
  default     = "AzureADMyOrg"

  validation {
    condition     = contains(["AzureADMyOrg", "AzureADMultipleOrgs", "AzureADandPersonalMicrosoftAccount", "PersonalMicrosoftAccount"], var.sign_in_audience)
    error_message = "Select a supported Entra sign-in audience."
  }
}

variable "group_membership_claims" {
  description = "Group claim types emitted in user tokens. Claims do not grant permissions by themselves."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for claim in var.group_membership_claims : contains(["None", "SecurityGroup", "DirectoryRole", "ApplicationGroup", "All"], claim)])
    error_message = "Group claims must use Entra's supported claim types."
  }
}

variable "identifier_uris" {
  description = "Application ID URIs for exposed APIs, subject to tenant verified-domain policy."
  type        = set(string)
  default     = []
}

variable "web" {
  description = "Web client callbacks, landing/logout URLs and explicit legacy implicit-flow switches. Omit for non-web applications."
  type = object({
    redirect_uris = optional(set(string), [])
    homepage_url  = optional(string)
    logout_url    = optional(string)
    implicit_grant = optional(object({
      access_token_issuance_enabled = optional(bool, false)
      id_token_issuance_enabled     = optional(bool, false)
    }), {})
  })
  default = null
}

variable "spa_redirect_uris" {
  description = "Single-page application callbacks, separate from confidential web clients."
  type        = set(string)
  default     = []
}

variable "public_client_redirect_uris" {
  description = "Native client callbacks, including localhost loopback URIs."
  type        = set(string)
  default     = []
}

variable "fallback_public_client_enabled" {
  description = "Enable public-client flows without redirect URIs, such as device code; leave disabled unless needed."
  type        = bool
  default     = false
}

variable "service_principal" {
  description = "Enterprise application account status and whether Entra requires an explicit app assignment to sign in."
  type = object({
    account_enabled     = optional(bool, true)
    assignment_required = optional(bool, false)
  })
  default = {}
}

variable "api" {
  description = "Exposed API settings and delegated scopes keyed by their token value. Caller supplies stable UUIDs."
  type = object({
    requested_access_token_version = optional(number, 2)
    known_client_applications      = optional(set(string), [])
    scopes = optional(map(object({
      id                         = string
      admin_consent_display_name = string
      admin_consent_description  = string
      user_consent_display_name  = optional(string)
      user_consent_description   = optional(string)
      type                       = optional(string, "Admin")
      enabled                    = optional(bool, true)
    })), {})
  })
  default = null

  validation {
    condition = var.api == null ? true : (
      contains([1, 2], var.api.requested_access_token_version) &&
      alltrue([for scope in values(var.api.scopes) : contains(["User", "Admin"], scope.type)]) &&
      length(distinct([for scope in values(var.api.scopes) : scope.id])) == length(var.api.scopes)
    )
    error_message = "Use token version 1 or 2, User/Admin scope types and distinct stable scope IDs."
  }
}

variable "app_roles" {
  description = "Roles exposed by this application, keyed by roles-claim value. Supply stable UUIDs; groups use the User member type."
  type = map(object({
    id                   = string
    display_name         = string
    description          = string
    allowed_member_types = optional(set(string), ["User"])
    enabled              = optional(bool, true)
  }))
  default = {}

  validation {
    condition = alltrue([for role in values(var.app_roles) :
      length(role.allowed_member_types) > 0 && alltrue([for member in role.allowed_member_types : contains(["User", "Application"], member)])
    ]) && length(distinct([for role in values(var.app_roles) : role.id])) == length(var.app_roles)
    error_message = "Use nonempty User/Application member types and distinct stable role IDs."
  }
}

variable "app_role_assignments" {
  description = "Inbound user/group/service-principal assignments keyed by purpose. role selects an app_roles key; omit only for an app with no exposed roles."
  type = map(object({
    principal_object_id = string
    role                = optional(string)
  }))
  default = {}
}

variable "required_resource_access" {
  description = "Requested permissions on other APIs keyed by purpose. Role means application permission; Scope means delegated permission. This does not grant consent."
  type = map(object({
    resource_app_id = string
    permissions = map(object({
      id   = string
      type = string
    }))
  }))
  default = {}

  validation {
    condition = alltrue([for api in values(var.required_resource_access) :
      length(api.permissions) > 0 && alltrue([for permission in values(api.permissions) : contains(["Role", "Scope"], permission.type)])
    ])
    error_message = "Each API needs permissions whose type is Role or Scope."
  }
}

variable "optional_claims" {
  description = "Additional token claims. This customizes claims; it does not configure a SAML enterprise application."
  type = object({
    id_token = optional(list(object({
      name                  = string
      source                = optional(string)
      essential             = optional(bool, false)
      additional_properties = optional(set(string), [])
    })), [])
    access_token = optional(list(object({
      name                  = string
      source                = optional(string)
      essential             = optional(bool, false)
      additional_properties = optional(set(string), [])
    })), [])
    saml2_token = optional(list(object({
      name                  = string
      source                = optional(string)
      essential             = optional(bool, false)
      additional_properties = optional(set(string), [])
    })), [])
  })
  default = null
}

variable "federated_credentials" {
  description = "Trusted external workload tokens keyed by credential display name. No client secret is created."
  type = map(object({
    issuer      = string
    subject     = string
    description = optional(string)
    audiences   = optional(list(string), ["api://AzureADTokenExchange"])
  }))
  default = {}
}

variable "application_permission_grants" {
  description = "Explicit outbound application-permission consent on other API service principals. Requires additional directory authority."
  type = map(object({
    resource_principal_id = string
    app_role_id           = string
  }))
  default = {}
}

variable "delegated_permission_grants" {
  description = "Explicit delegated-scope consent. Omitting user_object_id grants consent for ALL tenant users; configure only when intended."
  type = map(object({
    resource_principal_id = string
    scopes                = set(string)
    user_object_id        = optional(string)
  }))
  default = {}
}

variable "role_assignments" {
  description = "Scoped Azure RBAC roles granted to this application's service principal, separate from Entra app roles."
  type = map(object({
    scope                = string
    role_definition_name = string
  }))
  default = {}
}
