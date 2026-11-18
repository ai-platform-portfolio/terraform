mock_provider "aws" {
  mock_resource "aws_ssoadmin_permission_set" {
    defaults = { arn = "arn:aws:sso:::permissionSet/ssoins-1234567890abcdef/ps-1234567890abcdef" }
  }
}

variables {
  instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
  account_id   = "123456789012"
  name         = "ExampleBootstrap"
  description  = "Example scoped bootstrap authority"
  policy       = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["iam:GetRole"], Resource = "arn:aws:iam::123456789012:role/example" }] })
  principals   = { operator = { id = "12345678-1234-1234-1234-123456789012", type = "USER" } }
}

run "scoped_account_access" {
  command = apply

  assert {
    condition     = jsondecode(aws_ssoadmin_permission_set_inline_policy.this.inline_policy) == jsondecode(var.policy)
    error_message = "The permission set must preserve the caller's exact policy."
  }

  assert {
    condition     = aws_ssoadmin_account_assignment.this["operator"].target_id == var.account_id && aws_ssoadmin_account_assignment.this["operator"].principal_id == var.principals.operator.id && aws_ssoadmin_account_assignment.this["operator"].principal_type == "USER" && aws_ssoadmin_account_assignment.this["operator"].permission_set_arn == aws_ssoadmin_permission_set.this.arn
    error_message = "Access must bind the declared Identity Store principal to this permission set and account."
  }
}

run "reject_interactive_duration_as_role_duration" {
  command = plan
  variables { session_duration = "P90D" }
  expect_failures = [var.session_duration]
}

run "reject_wrong_identity_type" {
  command = plan
  variables { principals = { operator = { id = "example", type = "SERVICE_ACCOUNT" } } }
  expect_failures = [var.principals]
}
