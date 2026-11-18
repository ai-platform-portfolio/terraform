output "permission_set_arn" {
  description = "Permission set provisioned into the target account."
  value       = aws_ssoadmin_permission_set.this.arn
}

output "role_name" {
  description = "Native AWS CLI sso_role_name value."
  value       = aws_ssoadmin_permission_set.this.name
}
