# PostgreSQL roles

Shared native Atlas configuration for one caller's PostgreSQL roles. Like the
Terraform modules, `main.hcl` contains the configuration and `variables.hcl`
declares its inputs. The caller owns deployment choices and repetition.

## Usage

Pin a checkout of this library to a full Git commit. Keep the application's
schema alongside its code. Supply inputs in the application's `atlas.hcl`:

```hcl
atlas {
  cloud {
    org = "ai-platform-portfolio"
  }
}

variable "schema_dir" {
  type    = string
  default = "schema"
}

variable "role_names" {
  type    = list(string)
  default = ["orders_owner", "orders_migrator", "orders_app"]
}

variable "passwords" {
  type = map(string)
  default = {
    migrator = getenv("ORDERS_MIGRATOR_PASSWORD")
    runtime  = getenv("ORDERS_RUNTIME_PASSWORD")
  }
}
```

Keep schema inputs in `schema/variables.pg.hcl`:

```hcl
variable "passwords" {
  type = map(string)
}
```

Keep related resources in `schema/main.pg.hcl`:

```hcl
role "orders_owner" {}

user "orders_migrator" {
  password  = var.passwords["migrator"]
  member_of = [role.orders_owner]
}

user "orders_app" {
  password = var.passwords["runtime"]
}
```

Add the role/user blocks and password entries the application needs. The library
has no fixed role count or named migrator/runtime inputs. Atlas role names remain
literal HCL labels; `name` does not override them. Repeated callers belong in the
consuming delivery configuration, following the caller-owned repetition used by
`gitops/bootstrap`. This module contains no multi-application dispatcher.

Use Atlas **v1.3.6** and authenticate to the Atlas Pro organization. Run from the
application directory, replacing `../library` with your pinned checkout:

```sh
export ATLAS_DEV_URL=docker://postgres/18.6/dev
atlas schema validate --env roles --config file://../library/atlas/postgres/variables.hcl,file://../library/atlas/postgres/main.hcl,file://atlas.hcl
atlas schema lint --env roles --config file://../library/atlas/postgres/variables.hcl,file://../library/atlas/postgres/main.hcl,file://atlas.hcl,file://../library/atlas/postgres/lint.hcl --var policy_file=../library/atlas/postgres/roles.rule.hcl
```

All paths resolve from the working directory. Keep schema tests in the application.
Use a separate disposable PostgreSQL instance for dev/tests, since roles are
instance-wide. Supply `ATLAS_ROLE_URL` through secret delivery using a direct TLS
connection, not a transaction-mode pooler. Unset `ATLAS_DEV_URL` for role apply.

## Inputs

| Name | Type | Default | Purpose |
| --- | --- | --- | --- |
| `schema_dir` | string | required | Caller-owned native schema directory |
| `role_names` | list(string) | required | Exact role ownership scope |
| `passwords` | map(string) | `{}` | Secret values referenced by the schema |
| `role_url` | string | `ATLAS_ROLE_URL` | Role-manager connection |
| `dev_url` | string | `ATLAS_DEV_URL` | Disposable dev/test connection |
| `policy_file` | string | empty | Rule path when loading `lint.hcl` |

Empty/wildcard/overlong role names and empty password values are rejected.
The exact scope protects unlisted roles; schemas, objects and grants are disabled.
Keep scope names stable: removing a name relinquishes management; removing its
HCL definition while retaining its scope can plan deletion. Review SQL before apply.
The shared native lint policy rejects administrative role/user attributes in CI.

## Validation and limits

Run `bash atlas/postgres/tests/test.sh` from the repository root with Docker and
Atlas Pro authentication. It calls the same module independently for two consumers,
runs five native SQL assertions for each, rejects unsafe attributes/scopes, and
checks restricted CREATEROLE apply preserves both consumers and unrelated objects.
Both runtime logins are tested before and after repeated apply. The small Bash
harness coordinates Atlas/Docker/PostgreSQL; no additional test language is needed.
CI requires the bot token as Actions secret `ATLAS_TOKEN`.

Measured on v1.3.6: password-bearing dev lint simulation of schema apply reports a
planned-state mismatch, so desired-state policy lint runs separately in CI and
role apply runs without the dev database/lint overlay. No runtime approval gate
is claimed. The restricted role manager also reapplies supplied passwords because
it cannot compare stored verifiers. Credentials remain valid; repeat SQL plans
are not empty. No password-catalog access is granted to avoid these writes.

The module creates roles only. Database creation, ownership, grants, migrations,
ordered cleanup and backup/recovery remain separate work. Owner-role membership
does not automatically set object ownership for a migrator. Existing CNPG-owned
roles remain outside this scope. The Atlas operator remains the intended runner;
chart source integration, reconcile/drift and approval acceptance are pending.
There are no Terraform provider/state or Atlantis schema changes.

References: [Atlas configuration](https://atlasgo.io/atlas-schema/projects),
[native schema tests](https://atlasgo.io/testing/schema),
[PostgreSQL security as code](https://atlasgo.io/guides/postgres/security-declarative).
