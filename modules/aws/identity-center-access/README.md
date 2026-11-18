# Identity Center account access

One permission set, caller-supplied native IAM policy and named user/group
assignments into one account. The caller owns iteration, Identity Store
provisioning and the existing Identity Center instance. Configure the AWS provider
in the instance's home region. No IAM users, access keys or managed administrator
policy are created.

`session_duration` defaults to `PT1H` and accepts up to `PT12H`. This is the
refreshable AWS role credential duration, **not** the interactive login duration.
The separate Identity Center interactive session can be configured up to 90 days
in the console; no supported resource in this module manages that setting or the
external SAML identity source. Account access requires an account-access-capable
Identity Center instance; creating an application-only instance is insufficient.

Consumers supply `instance_arn`, `account_id`, `name`, `description`, `policy` and
`principals = { operator = { id = "<identity-store-user-id>", type = "USER" } }`.
Entra object IDs are not Identity Store IDs. Use modern AWS CLI `sso-session`
configuration for refresh; no credential process is required.

Sources: [account assignments](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_account_assignment),
[interactive sessions](https://docs.aws.amazon.com/singlesignon/latest/userguide/user-interactive-sessions.html).
