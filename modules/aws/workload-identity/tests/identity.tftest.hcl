mock_provider "aws" {}

override_resource {
  target = aws_iam_openid_connect_provider.this
  values = { arn = "arn:aws:iam::123456789012:oidc-provider/issuer.example.test/cluster/" }
}

variables {
  name = "example-runtime"
  trust = {
    issuer   = "https://issuer.example.test/cluster/"
    audience = "sts.amazonaws.com"
    subject  = "system:serviceaccount:gateway:proxy"
  }
  policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"bedrock:InvokeModel\"],\"Resource\":[\"arn:aws:bedrock:eu-west-3:123456789012:inference-profile/eu.example\"]}]}"
}

run "exact_trust_and_caller_permissions" {
  command = apply

  assert {
    condition     = aws_iam_openid_connect_provider.this.url == "https://issuer.example.test/cluster/" && aws_iam_openid_connect_provider.this.client_id_list == toset(["sts.amazonaws.com"])
    error_message = "Only the declared issuer and audience may federate."
  }

  assert {
    condition = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0] == {
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = "arn:aws:iam::123456789012:oidc-provider/issuer.example.test/cluster/" }
      Condition = { StringEquals = {
        "issuer.example.test/cluster/:aud" = "sts.amazonaws.com"
        "issuer.example.test/cluster/:sub" = "system:serviceaccount:gateway:proxy"
      } }
    }
    error_message = "Wrong subjects, audiences and other identity providers must have no trust statement."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.this.policy) == jsondecode(var.policy) && aws_iam_role_policy.this.role == aws_iam_role.this.id
    error_message = "The workload receives only the supplied native permission document."
  }
}

run "reject_wildcard_subject" {
  command = plan
  variables {
    trust = { issuer = "https://issuer.example.test", audience = "sts.amazonaws.com", subject = "*" }
  }
  expect_failures = [var.trust]
}

run "reject_empty_audience" {
  command = plan
  variables {
    trust = { issuer = "https://issuer.example.test", audience = "", subject = "system:serviceaccount:gateway:proxy" }
  }
  expect_failures = [var.trust]
}
