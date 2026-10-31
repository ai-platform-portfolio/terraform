#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/examples/preview"
config=file://../../postgres/atlas.hcl,file://atlas.hcl
container="atlas-library-test-$$-${RANDOM}"
scratch=$(mktemp -d)

cleanup() {
  atlas tool docker kill --name "$container" >/dev/null 2>&1 || true
  rm -rf "$scratch"
}
trap cleanup EXIT

# Disposable test credentials only; never consume a deployment database URL.
export ATLAS_MIGRATOR_PASSWORD=atlas-test-migrator
export ATLAS_RUNTIME_PASSWORD=atlas-test-runtime
export ATLAS_DEV_URL=docker://postgres/18.6/dev
export ATLAS_ROLE_URL
ATLAS_ROLE_URL=$(atlas tool docker --url docker://postgres/18.6/atlas --name "$container")

atlas schema validate --env roles --config "$config"
atlas schema test --env roles --config "$config"
atlas schema lint --env roles --config "$config,file://../../postgres/lint.hcl" --var policy_file=../../postgres/roles.rule.hcl

# Prove the shared rule rejects both a role and a user with elevated privileges.
sed 's/create_db   = false/create_db   = true/g' roles.pg.hcl >"$scratch/unsafe.pg.hcl"
if atlas schema lint --env roles --config "$config,file://../../postgres/lint.hcl" \
  --var policy_file=../../postgres/roles.rule.hcl --var "roles_file=$scratch/unsafe.pg.hcl" >"$scratch/unsafe-role" 2>&1; then
  echo 'Administrative role attributes were accepted' >&2
  exit 1
fi
grep -q 'role preview_pr42_owner must not have administrative privileges' "$scratch/unsafe-role"
grep -q 'user preview_pr42_app must not have administrative privileges' "$scratch/unsafe-role"

# Empty scope would mean unrestricted inspection; wildcard scope is also unsafe.
for scope in '[]' '["*"]'; do
  printf 'variable "role_names" {\n  type = list(string)\n  default = %s\n}\n' "$scope" >"$scratch/scope.hcl"
  if atlas schema validate --env roles --config "$config,file://$scratch/scope.hcl" >"$scratch/invalid-scope" 2>&1; then
    echo "Invalid role scope was accepted: $scope" >&2
    exit 1
  fi
  if ! grep -q 'Provide at least one exact role name' "$scratch/invalid-scope"; then
    echo "Scope check failed for an unexpected reason" >&2
    exit 1
  fi
done

# Role-only apply needs no dev database. Passwords currently fail Atlas's dev
# lint simulation; lint the desired role attributes separately above.
unset ATLAS_DEV_URL

# SQL assertions live in Atlas tests above. This separate target checks that the
# real apply preserves objects outside its include filter with a CREATEROLE login.
docker exec -i "$container" psql -U postgres -d atlas -v ON_ERROR_STOP=1 <<'SQL'
CREATE ROLE unrelated_owner;
CREATE TABLE unrelated_data (id integer PRIMARY KEY);
INSERT INTO unrelated_data VALUES (42);
CREATE ROLE atlas_test_manager LOGIN CREATEROLE PASSWORD 'atlas-test-manager';
SQL

cat >"$scratch/manager.hcl" <<'HCL'
env "roles" {
  url = urluserinfo(var.role_url, "atlas_test_manager", "atlas-test-manager")
}
HCL
apply_config="$config,file://$scratch/manager.hcl"

atlas schema apply --env roles --config "$apply_config" --dry-run
atlas schema apply --env roles --config "$apply_config" --auto-approve

docker exec -i "$container" psql -U postgres -d atlas -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'unrelated_owner' AND NOT rolcanlogin)
     OR (SELECT count(*) FROM unrelated_data WHERE id = 42) <> 1
     OR (SELECT count(*) FROM pg_roles WHERE rolname IN
         ('preview_pr42_owner', 'preview_pr42_migrator', 'preview_pr42_app')) <> 3 THEN
    RAISE EXCEPTION 'Scoped apply changed unrelated objects or failed to create the profile';
  END IF;
END $$;
SQL

# Atlas cannot compare stored passwords with this restricted login. Reapply must
# contain only the two password writes, with no structural/ownership changes.
atlas schema apply --env roles --config "$apply_config" --dry-run >"$scratch/reapply"
cat "$scratch/reapply"
# The pinned CLI prints each statement in both the plan and dry-run sections.
test "$(grep -c -- '-> ' "$scratch/reapply")" -eq 4
test "$(grep -c -- '-> ALTER ROLE .* PASSWORD ' "$scratch/reapply")" -eq 4

for pass in before after; do
  docker exec -e PGPASSWORD="$ATLAS_RUNTIME_PASSWORD" "$container" \
    psql -h 127.0.0.1 -U preview_pr42_app -d atlas -v ON_ERROR_STOP=1 -c 'SELECT current_user'
  if [ "$pass" = before ]; then
    atlas schema apply --env roles --config "$apply_config" --auto-approve
  fi
done
echo 'Role policy, scope rejection, isolation and repeated-login checks passed'
