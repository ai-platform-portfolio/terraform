variable "name" {
  description = "Azure Kubernetes Fleet Manager name."
  type        = string
}

variable "location" {
  description = "Azure region for the fleet resource; members can be in other regions."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group that owns the shared fleet."
  type        = string
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
