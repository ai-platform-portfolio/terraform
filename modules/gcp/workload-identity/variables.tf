variable "project_id" {
  description = "Existing Google project supplied externally."
  type        = string
  sensitive   = true
}

variable "name" {
  description = "Prefix for the runtime pool and service account."
  type        = string
}

variable "tenant_id" {
  description = "Authorized Entra tenant."
  type        = string
  sensitive   = true
}

variable "principal_id" {
  description = "Authorized existing managed identity object ID."
  type        = string
  sensitive   = true
}

variable "issuer" {
  description = "Exact issuer of the version 1 Entra token."
  type        = string
  sensitive   = true
}

variable "audience" {
  description = "Dedicated Entra application ID URI for Google federation."
  type        = string
  sensitive   = true
}

variable "role_value" {
  description = "Required application role claim."
  type        = string
  default     = "Federate.Workload"
}

variable "provider_id" {
  description = "Stable runtime provider ID."
  type        = string
  default     = "azure"
}

variable "role_id" {
  description = "Project custom inference role identifier."
  type        = string
  default     = "modelGatewayInference"
}

variable "inference_permissions" {
  description = "Permissions required for Gemini content generation and API usage."
  type        = set(string)
  default     = ["aiplatform.endpoints.predict", "serviceusage.services.use"]
}
