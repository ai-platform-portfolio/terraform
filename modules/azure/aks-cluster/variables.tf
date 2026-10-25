variable "name" {
  description = "AKS cluster name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID."
  type        = string
}

variable "kubernetes_version" {
  description = "Explicit AKS Kubernetes version supported in the target region."
  type        = string
}

variable "vnet_subnet_id" {
  description = "System node pool subnet resource ID."
  type        = string
}

variable "admin_group_object_ids" {
  description = "Entra security groups granted Kubernetes cluster admin."
  type        = list(string)

  validation {
    condition     = length(var.admin_group_object_ids) > 0
    error_message = "At least one Entra admin group is required."
  }
}

variable "azure_rbac_enabled" {
  description = "Use Azure RBAC for Entra-authenticated Kubernetes users and workload identities. Existing callers retain Kubernetes RBAC by default."
  type        = bool
  default     = false
}

variable "authorized_ip_ranges" {
  description = "CIDRs allowed to access the public AKS API, including the deployment runner."
  type        = list(string)

  validation {
    condition     = length(var.authorized_ip_ranges) > 0
    error_message = "Supply explicit API access CIDRs."
  }
}

variable "system_node_pool" {
  description = "Fixed-size system pool; applications use a separate user pool."
  type = object({
    vm_size         = optional(string, "Standard_D4s_v5")
    node_count      = optional(number, 1)
    os_disk_size_gb = optional(number, 64)
  })
  default = {}
}

variable "user_node_pools" {
  description = "Application pools keyed by AKS pool name (up to 12 lowercase alphanumeric characters)."
  type = map(object({
    vm_size         = string
    node_count      = number
    vnet_subnet_id  = string
    os_disk_size_gb = optional(number, 64)
  }))
  default = {}
}

variable "max_pods" {
  description = "Explicit per-node pod capacity."
  type        = number
  default     = 110
}

variable "sku_tier" {
  description = "Free for portfolio; Standard for an API uptime SLA."
  type        = string
  default     = "Free"
}

variable "private_cluster_enabled" {
  description = "Use a private API; requires deployment runner network connectivity."
  type        = bool
  default     = false
}

variable "pod_cidr" {
  description = "Azure CNI overlay pod range; must not overlap connected networks."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Kubernetes service range; must not overlap connected networks."
  type        = string
  default     = "10.240.0.0/16"
}

variable "dns_service_ip" {
  description = "DNS IP within the service range."
  type        = string
  default     = "10.240.0.10"
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}

variable "container_registries" {
  description = "Existing registry resource IDs keyed by purpose; grants AcrPull to the AKS-managed kubelet identity."
  type        = map(string)
  default     = {}
}

variable "fleet_membership" {
  description = "Optional enrollment in an existing Azure Kubernetes Fleet Manager, owned by this cluster root."
  type = object({
    fleet_id = string
    name     = string
    group    = string
  })
  default = null
}
