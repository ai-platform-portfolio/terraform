variable "name" {
  description = "Foundry account name and unique Entra-enabled custom subdomain."
  type        = string
}

variable "resource_group_name" {
  description = "Existing environment resource group."
  type        = string
}

variable "location" {
  description = "Foundry resource and regional inference location."
  type        = string
}

variable "sku_name" {
  description = "Foundry account SKU. Model deployment capacity is configured separately."
  type        = string
  default     = "S0"
}

variable "account_settings" {
  description = "Foundry account settings. The secure, project-enabled defaults can be overridden by callers."
  type = object({
    kind                          = optional(string, "AIServices")
    custom_subdomain_name         = optional(string)
    project_management_enabled    = optional(bool, true)
    public_network_access_enabled = optional(bool, false)
    local_auth_enabled            = optional(bool, false)
  })
  default = {}
}

variable "managed_identity_id" {
  description = "Existing shared user-assigned identity attached to the Foundry account."
  type        = string
}

variable "identity_type" {
  description = "Identity type for the account and its projects."
  type        = string
  default     = "UserAssigned"
}

variable "network_acls" {
  description = "Account network ACL settings."
  type = object({
    default_action = optional(string, "Deny")
    bypass         = optional(string, "None")
  })
  default = {}
}

variable "inference_principal_id" {
  description = "Optional existing principal for an account-scoped inference role; leave null when another owner manages inference RBAC."
  type        = string
  default     = null
  sensitive   = true
}

variable "inference_role_name" {
  description = "Account-scoped inference role, without model deployment permissions."
  type        = string
  default     = "Cognitive Services OpenAI User"
}

variable "inference_principal_type" {
  description = "Azure RBAC principal type for the inference identity."
  type        = string
  default     = "ServicePrincipal"
}

variable "skip_service_principal_aad_check" {
  description = "Skip the Entra propagation check for a newly created inference principal."
  type        = bool
  default     = true
}

variable "private_endpoint_location" {
  description = "Region of the private endpoint VNet; may differ from the Foundry account region."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Existing private endpoint subnet. Its NSG must permit approved clients."
  type        = string
}

variable "private_endpoint_settings" {
  description = "Private endpoint naming, connection and DNS zone group settings."
  type = object({
    name                 = optional(string)
    name_suffix          = optional(string, "-pe")
    connection_name      = optional(string)
    subresource_names    = optional(list(string), ["account"])
    is_manual_connection = optional(bool, false)
    dns_zone_group_name  = optional(string, "foundry")
  })
  default = {}
}

variable "private_dns_zone_ids" {
  description = "Existing private DNS zones for services.ai.azure.com, openai.azure.com and cognitiveservices.azure.com."
  type        = list(string)

  validation {
    condition = alltrue([
      for zone in ["privatelink.openai.azure.com", "privatelink.cognitiveservices.azure.com", "privatelink.services.ai.azure.com"] :
      anytrue([for id in var.private_dns_zone_ids : endswith(lower(id), "/${zone}")])
    ])
    error_message = "All three Foundry private DNS zones are required."
  }
}

variable "allowed_deployment_skus" {
  description = "Explicitly approved processing scope. Standard remains within the resource geography; global and data-zone deployments require a reviewed override."
  type        = set(string)
  default     = ["Standard"]
}

variable "projects" {
  description = "Foundry projects keyed by stable name, reusing the environment identity."
  type = map(object({
    display_name = optional(string)
    description  = optional(string)
  }))
  default = {}
}

variable "deployments" {
  description = "Model deployments keyed by stable deployment name; versions and capacity are explicit."
  type = map(object({
    format                 = optional(string, "OpenAI")
    model_name             = string
    model_version          = string
    sku_name               = optional(string, "Standard")
    capacity               = number
    version_upgrade_option = optional(string, "NoAutoUpgrade")
    rai_policy_name        = optional(string, "Microsoft.DefaultV2")
  }))
  default = {}

  validation {
    condition = alltrue([
      for deployment in values(var.deployments) :
      deployment.capacity >= 1 && floor(deployment.capacity) == deployment.capacity &&
      contains(["NoAutoUpgrade", "OnceCurrentVersionExpired", "OnceNewDefaultVersionAvailable"], deployment.version_upgrade_option)
    ])
    error_message = "Deployment capacity must be a positive integer and the version upgrade option must be supported."
  }
}

variable "timeouts" {
  description = "Foundry account and model deployment operation timeouts."
  type = object({
    create = optional(string, "1h")
    update = optional(string, "1h")
    delete = optional(string, "1h")
  })
  default = {}
}

variable "tags" {
  description = "Environment ownership and cost allocation tags."
  type        = map(string)
  default     = {}
}
