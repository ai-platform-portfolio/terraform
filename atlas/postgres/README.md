# PostgreSQL roles

Reusable native Atlas configuration, arranged like the other modules:
`main.hcl` contains the environment/loop, `variables.hcl` declares inputs, and
`lint.hcl` loads the shared `roles.rule.hcl` CI policy. Usage is documented here;
`tests/` contains validation fixtures rather than a separate examples directory.

## Usage

Check out the library at a full Git commit alongside the application repository.
The application keeps its own `atlas.hcl` consumer configuration and `schema/`
files. For example, in the application's `atlas.hcl`:

```hcl
atlas {
  cloud {
    org = "ai-platform-portfolio"
  }
}

variable "targets" {
  type = map(object({
    schema_dir = string
    role_names = list(string)
    passwords  = map(string)
  }))

  default = {
    orders = {
      schema_dir = "schema"
      role_names = ["orders_owner", "orders_migrator", "orders_app"]
      passwords = {
        migrator = getenv("ORDERS_MIGRATOR_PASSWORD")
        runtime  = getenv("ORDERS_RUNTIME_PASSWORD")
      }
    }
  }
}
```

Keep schema input declarations in `schema/variables.pg.hcl`:

```hcl
variable "passwords" {
  type = map(string)
}
```

Put the application's related resources in `schema/main.pg.hcl`:

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

The owner cannot log in; the migrator inherits ownership-group membership; the
runtime user has no ownership membership. Add any number of literal role/user
blocks and password-map entries; there are no fixed migrator/runtime inputs in
the shared library. Split related schema resources into additional `.pg.hcl`
files in the same directory as needed. Atlas loads that directory together.

These roles do not have administrative privileges. This module does not create
a database, assign database/object ownership, grant runtime access or apply
application migrations. Membership alone does not make objects created by the
migrator belong to the owner role; migrations must use the intended ownership
identity. Database access and cross-database isolation need integration tests.

## Multiple targets and inputs

Add entries to `targets` for more applications/previews on the shared server.
The native environment uses `for_each` over the map's keys; each target supplies
its own schema directory, exact role names and password map. Keep role scopes
disjoint on the same server. New environments/servers use their own connection
and caller configuration, like separate Terraform deployment roots.

Atlas v1.3.6 requires a set of keys for this loop; a map of objects directly is
unsupported. Role/user names remain literal HCL block labels: a role's `name`
attribute does not override its label. This loop repeats scoped environments,
not dynamically named SQL role blocks. That is the explicit-name tradeoff agreed
for native HCL; adding a SQL/HCL templating layer is a separate decision.

| Input | Purpose |
| --- | --- |
| `targets` | Required map of schema directories, role-name lists and secret maps |
| `target` | Optional map key to select one target; empty processes all on apply |
| `role_url` | Shared role-manager URL; defaults to secret-delivered `ATLAS_ROLE_URL` |
| `dev_url` | Dedicated disposable dev instance; defaults to `ATLAS_DEV_URL` |
| `policy_file` | Rule-file path supplied when loading the CI lint overlay |

Install Atlas **v1.3.6**, authenticate to the Atlas Pro organization and start
Docker. From the application directory, load library inputs and main configuration
before the caller's configuration (replace `../library` with your pinned checkout):

```sh
export ATLAS_DEV_URL=docker://postgres/18.6/dev
atlas schema validate --env roles --config file://../library/atlas/postgres/variables.hcl,file://../library/atlas/postgres/main.hcl,file://atlas.hcl --var target=orders
atlas schema test --env roles --config file://../library/atlas/postgres/variables.hcl,file://../library/atlas/postgres/main.hcl,file://atlas.hcl --var target=orders ./tests
atlas schema lint --env roles --config file://../library/atlas/postgres/variables.hcl,file://../library/atlas/postgres/main.hcl,file://atlas.hcl,file://../library/atlas/postgres/lint.hcl --var policy_file=../library/atlas/postgres/roles.rule.hcl --var target=orders
```

Validate/lint/test accept one environment, so select a target when the map has
multiple entries. Apply supports the complete native loop; use `target` to limit
it when required. Invalid target keys are rejected rather than silently doing
nothing. Keep application schema tests with the application.

Unset `ATLAS_DEV_URL` for role/password apply. Role-only mode needs no dev DB.
Never share a dev PostgreSQL instance with deployment databases: roles are
instance-wide. Supply `ATLAS_ROLE_URL` through secret delivery using a direct TLS
connection, not a transaction-mode pooler. Validation/tests need no deployment
URL. All paths resolve from the working directory.

## Scope and safety

Only the exact `targets[*].role_names` are included; empty lists, wildcard patterns and
overlong names are rejected. Permissions are disabled. Unlisted roles, schemas,
tables and grants are outside this environment’s ownership. Keep the scope stable:
removing a name from it relinquishes management rather than deleting that role.
Removing a role from HCL while keeping its name in scope can plan its deletion.
Review SQL before applying and handle database dependencies explicitly.

The separate lint overlay rejects SUPERUSER, CREATEDB, CREATEROLE, replication and
RLS bypass attributes in roles and users. It is a desired-state CI check, not a
deployment approval or deletion guard. Password management is explicitly enabled
through `sensitive = ALLOW`; credentials come from environment
variables and must not be committed. The application overlay pins the Atlas Cloud
organization so an absent/wrong login fails.

Two acceptance-test findings affect delivery design. With plaintext passwords,
dev-database lint simulation of `schema apply` reports a planned-state mismatch
(observed on v1.3.0 and v1.3.6). Therefore the library keeps native schema lint in
CI and performs role-only apply without a dev database or that lint overlay.
Do not claim a runtime lint/review gate is enabled here. Protected deployment
approval is still work for the operator integration.

Atlas also plans to reapply supplied passwords when a restricted CREATEROLE
account cannot inspect their stored verifiers. Reapplying the same password
keeps the login credential stable, but is **not an empty SQL plan**. Stored SCRAM
verifiers produced an empty replan with a superuser, but not with the restricted
account; this library does not grant password-catalog access to obtain that.
Operator drift/reconcile behavior and deployment approvals must be tested before
adopting the library in the cluster. No new hash-generation/secret-storage flow
is introduced by this PR.

## Validation and delivery boundary

From the repository root, `bash atlas/postgres/tests/test.sh` runs native Atlas SQL assertions,
rejects unsafe scope inputs, applies to a separate disposable server containing
unrelated objects, and checks those survive. It uses a restricted CREATEROLE
login for apply, checks that the repeat plan contains only four password
writes across two targets, and verifies runtime authentication before and after repeated apply.
It also proves the shared policy rejects elevated role and user attributes. Five native SQL
assertions run independently for each target.
The script uses only Bash, Atlas and PostgreSQL’s bundled `psql` through Docker;
the small shell harness coordinates the real apply rather than replacing Atlas’s
native test framework. It overwrites deployment URL inputs with its own disposable
target and removes that container on exit. Test passwords are disposable fixtures.

The Atlas workflow pins CLI v1.3.6 and requires the Actions secret `ATLAS_TOKEN`
(an Atlas Pro bot token). Only dev databases run in CI; no cluster, registry
publication or deployment credentials are involved. Terraform checks continue
through the existing `ops-shared` workflow. Its current workflows have no Atlas
support, so this small Atlas-specific job uses the official setup action.

The Kubernetes operator remains the intended deployment runner. This PR supplies
the authoring/validation library only; the current application Helm chart still
generates role HCL. A separate PR must connect native sources to the operator,
including pinned artifacts and secret inputs. There is no Terraform Atlas
provider/state, Atlantis schema execution, existing-role adoption, automated
cleanup or rollback implementation here. Keep CNPG-owned roles outside this
scope. Database creation, ordered cleanup, backup/recovery and versioned
application migrations remain separate delivery work.

References: [Atlas project configuration](https://atlasgo.io/atlas-schema/projects),
[native schema tests](https://atlasgo.io/testing/schema),
[PostgreSQL security as code](https://atlasgo.io/guides/postgres/security-declarative).
