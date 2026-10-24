variable "display_name" {
  description = "Entra application display name."
  type        = string
}

variable "owners" {
  description = "Object IDs owning the application and its service principal."
  type        = set(string)
}

variable "sign_in_audience" {
  description = "Microsoft account types allowed to authenticate to the application."
  type        = string
  default     = "AzureADMyOrg"
}

variable "group_membership_claims" {
  description = "Group claim types emitted in user tokens, such as SecurityGroup."
  type        = set(string)
  default     = []
}

variable "web_redirect_uris" {
  description = "HTTPS callbacks for confidential web clients."
  type        = set(string)
  default     = []
}

variable "public_client_redirect_uris" {
  description = "Callbacks for native clients, including localhost loopback URIs."
  type        = set(string)
  default     = []
}

variable "federated_credentials" {
  description = "Trusted external workload tokens keyed by credential display name. No client secret is created."
  type = map(object({
    issuer    = string
    subject   = string
    audiences = optional(list(string), ["api://AzureADTokenExchange"])
  }))
  default = {}
}
