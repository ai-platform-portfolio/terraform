# Native Atlas PostgreSQL configuration

The shared `postgres/atlas.hcl` supplies a role-management environment, exact-name
scope and secret inputs. `postgres/lint.hcl` and `roles.rule.hcl` supply a native
CI policy rejecting administrative role attributes. Applications own their HCL.
The [preview example](examples/preview) declares three roles:

| Role | Purpose |
| --- | --- |
| `preview_pr42_owner` | Ownership group with no login |
| `preview_pr42_migrator` | Migration login, member of the ownership group |
| `preview_pr42_app` | Runtime login without ownership membership |

These roles have no administrative privileges. This example creates roles only:
it does not create a database, assign database/object ownership, grant runtime
access or apply application migrations. Membership alone does not make objects
created by the migrator belong to the owner role; migrations must deliberately
use the intended ownership identity. Database access, grants and cross-database
isolation need separate integration tests.

## Consume

Check out this library at a full Git commit alongside the application repository.
Keep the application’s `roles.pg.hcl` and small `atlas.hcl` overlay with its code.
Run from the application directory, loading the library config first and the
application config second. Paths resolve from the working directory.

For the included example, install Atlas **v1.3.6**, log in to the portfolio’s
Atlas Pro organization and start Docker. Supply `ATLAS_MIGRATOR_PASSWORD` and
`ATLAS_RUNTIME_PASSWORD` through your secret manager or local environment, then:

```sh
cd atlas/examples/preview
export ATLAS_DEV_URL=docker://postgres/18.6/dev
atlas schema validate --env roles --config file://../../postgres/atlas.hcl,file://atlas.hcl
atlas schema test --env roles --config file://../../postgres/atlas.hcl,file://atlas.hcl
atlas schema lint --env roles --config file://../../postgres/atlas.hcl,file://atlas.hcl,file://../../postgres/lint.hcl --var policy_file=../../postgres/roles.rule.hcl
```

`ATLAS_DEV_URL` is only for validation, schema lint and tests. Unset it for
role/password apply; the role-only mode needs no dev database. Never share a dev
PostgreSQL instance with deployment
databases: roles are instance-wide. `ATLAS_ROLE_URL` selects the deployment
connection for planning/applying; use a direct TLS connection and secret delivery,
never a transaction-mode pooler or checked-in URL. No deployment URL is needed
for the validation/tests above.

For another application, change the three literal role labels, the `member_of`
reference, and the `role_names` scope together. Atlas does not use a role’s `name`
attribute to override its literal HCL label (verified with v1.3.0). Explicit names
are the accepted small duplication; no HCL/SQL templating layer is introduced.
`roles_file` defaults to `roles.pg.hcl` and can be overridden in the consumer.

## Scope and safety

Only the exact `role_names` are included; empty lists, wildcard patterns and
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

From the repository root, `bash atlas/test.sh` runs native Atlas SQL assertions,
rejects unsafe scope inputs, applies to a separate disposable target containing
unrelated objects, and checks those survive. It uses a restricted CREATEROLE
login for apply, checks that the repeat plan contains only the two password
writes, and verifies runtime authentication before and after repeated apply.
It also proves the shared policy rejects elevated role and user attributes.
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
