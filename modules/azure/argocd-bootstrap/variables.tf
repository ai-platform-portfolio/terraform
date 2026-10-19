variable "name" {
  description = "Helm release name."
  type        = string
  default     = "argocd"
}
variable "namespace" {
  description = "ArgoCD namespace."
  type        = string
  default     = "argocd"
}
variable "chart_version" {
  description = "Explicit argo-cd chart version."
  type        = string
}
variable "values" {
  description = "Ordered YAML Helm values documents; do not include credentials."
  type        = list(string)
  default     = []
}
variable "timeout" {
  description = "Release readiness timeout in seconds."
  type        = number
  default     = 900
}
