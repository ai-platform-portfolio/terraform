terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

locals {
  issuer = trimprefix(var.trust.issuer, "https://")
}

resource "aws_iam_openid_connect_provider" "this" {
  url            = var.trust.issuer
  client_id_list = [var.trust.audience]
}

resource "aws_iam_role" "this" {
  name = var.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.this.arn }
      Condition = {
        StringEquals = {
          "${local.issuer}:aud" = var.trust.audience
          "${local.issuer}:sub" = var.trust.subject
        }
      }
    }]
  })
}

# Permissions are explicit caller intent; no managed administrator policy.
resource "aws_iam_role_policy" "this" {
  name   = "workload"
  role   = aws_iam_role.this.id
  policy = var.policy
}
