output "role_arn" {
  description = "Role assumed by the supplied Kubernetes subject."
  value       = aws_iam_role.this.arn
  sensitive   = true

  depends_on = [aws_iam_role_policy.this]
}
