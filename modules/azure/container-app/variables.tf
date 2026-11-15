variable "name" {
  description = "Container App name, unique within its environment and resource group."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group."
  type        = string
}

variable "container_app_environment_id" {
  description = "Existing Container Apps environment resource ID."
  type        = string
}

variable "managed_identity_id" {
  description = "Caller-owned user-assigned identity for the app and optional registry pull."
  type        = string
}

variable "registry_server" {
  description = "Optional private registry hostname; the caller grants AcrPull to the identity."
  type        = string
  default     = null
}

variable "image" {
  description = "Published container image pinned by digest."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+/[a-z0-9/._-]+@sha256:[a-f0-9]{64}$", var.image))
    error_message = "Supply a registry/repository@sha256:digest image reference."
  }
}

variable "environment_variables" {
  description = "Non-secret environment variables. Never put credentials in this map."
  type        = map(string)
  default     = {}
}

variable "cpu" {
  description = "Allocated vCPU, using a Consumption-supported CPU/memory combination."
  type        = number
  default     = 0.25
}

variable "memory" {
  description = "Allocated memory, using a Consumption-supported CPU/memory combination."
  type        = string
  default     = "0.5Gi"
}

variable "replicas" {
  description = "Replica bounds; opt into a warm replica explicitly."
  type = object({
    min = optional(number, 0)
    max = optional(number, 1)
  })
  default = {}

  validation {
    condition     = var.replicas.min >= 0 && var.replicas.max >= 1 && var.replicas.max >= var.replicas.min && floor(var.replicas.min) == var.replicas.min && floor(var.replicas.max) == var.replicas.max
    error_message = "Replica bounds must be integers with 0 <= min <= max and max >= 1."
  }
}

variable "target_port" {
  description = "HTTP container port used for ingress and probes."
  type        = number
  default     = 8080
}

variable "external_ingress_enabled" {
  description = "Explicitly opt into public HTTPS ingress; otherwise ingress is environment-internal."
  type        = bool
  default     = false
}

variable "health_probe_path" {
  description = "HTTP path for liveness and readiness probes."
  type        = string
  default     = "/healthz"
}

variable "custom_domain" {
  description = "Optional single hostname in an existing Azure DNS zone, with managed HTTPS. The module owns this app's custom-domain list."
  type = object({
    hostname            = string
    zone_name           = string
    resource_group_name = string
  })
  default = null

  validation {
    condition     = var.custom_domain == null ? true : endswith(var.custom_domain.hostname, ".${var.custom_domain.zone_name}")
    error_message = "Use a subdomain within the configured DNS zone."
  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
