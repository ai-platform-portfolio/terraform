terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

resource "aws_ssoadmin_permission_set" "this" {
  instance_arn     = var.instance_arn
  name             = var.name
  description      = var.description
  session_duration = var.session_duration
}

resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this.arn
  inline_policy      = var.policy
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = var.principals

  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this.arn
  principal_id       = each.value.id
  principal_type     = each.value.type
  target_id          = var.account_id
  target_type        = "AWS_ACCOUNT"

  depends_on = [aws_ssoadmin_permission_set_inline_policy.this]
}
