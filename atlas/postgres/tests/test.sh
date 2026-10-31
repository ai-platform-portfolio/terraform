#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
base=file://../variables.hcl,file://../main.hcl
config="$base,file://atlas.hcl"
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

for target in preview_pr42 preview_pr43; do
  atlas schema validate --env roles --config "$config" --var "target=$target"
  atlas schema test --env roles --config "$config" --var "target=$target"
  atlas schema lint --env roles --config "$config,file://../lint.hcl" \
    --var policy_file=../roles.rule.hcl --var "target=$target"
done

# Prove the shared rule rejects both a role and a user with elevated privileges.
mkdir "$scratch/unsafe"
cp schema42/variables.pg.hcl "$scratch/unsafe/variables.pg.hcl"
sed 's/create_db   = false/create_db   = true/g' schema42/main.pg.hcl >"$scratch/unsafe/main.pg.hcl"
sed "s|\"schema42\"|\"$scratch/unsafe\"|" atlas.hcl >"$scratch/unsafe-target.hcl"
if atlas schema lint --env roles --config "$base,file://$scratch/unsafe-target.hcl,file://../lint.hcl" \
  --var policy_file=../roles.rule.hcl --var target=preview_pr42 >"$scratch/unsafe-role" 2>&1; then
  echo 'Administrative role attributes were accepted' >&2
  exit 1
fi
grep -q 'role preview_pr42_owner must not have administrative privileges' "$scratch/unsafe-role"
grep -q 'user preview_pr42_app must not have administrative privileges' "$scratch/unsafe-role"

# Empty scope would mean unrestricted inspection; wildcard scope is also unsafe.
for scope in '[]' '["*"]'; do
  cat >"$scratch/scope.hcl" <<HCL
variable "targets" {
  type = map(object({schema_dir=string, role_names=list(string), passwords=map(string)}))
  default = {
    invalid_scope = {
      schema_dir = "schema42"
      role_names = $scope
      passwords = {
        migrator = getenv("ATLAS_MIGRATOR_PASSWORD")
        runtime  = getenv("ATLAS_RUNTIME_PASSWORD")
      }
    }
  }
}
HCL
  if atlas schema validate --env roles --config "$config,file://$scratch/scope.hcl" >"$scratch/invalid-scope" 2>&1; then
    echo "Invalid role scope was accepted: $scope" >&2
    exit 1
  fi
  if ! grep -q 'Provide targets' "$scratch/invalid-scope"; then
    echo "Scope check failed for an unexpected reason" >&2
    exit 1
  fi
done

# A misspelled selector must fail instead of silently selecting zero targets.
if atlas schema validate --env roles --config "$config" --var target=missing >"$scratch/missing-target" 2>&1; then
  echo 'Unknown target was accepted' >&2
  exit 1
fi
grep -q 'The selected target must exist in targets' "$scratch/missing-target"

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
         ('preview_pr42_owner', 'preview_pr42_migrator', 'preview_pr42_app',
          'preview_pr43_owner', 'preview_pr43_migrator', 'preview_pr43_app')) <> 6 THEN
    RAISE EXCEPTION 'Scoped apply changed unrelated objects or failed to create the profile';
  END IF;
END $$;
SQL

# Atlas cannot compare stored passwords with this restricted login. Reapply must
# contain only the four password writes, with no structural/ownership changes.
atlas schema apply --env roles --config "$apply_config" --dry-run >"$scratch/reapply"
cat "$scratch/reapply"
# The pinned CLI prints each statement in both the plan and dry-run sections.
test "$(grep -c -- '-> ' "$scratch/reapply")" -eq 8
test "$(grep -c -- '-> ALTER ROLE .* PASSWORD ' "$scratch/reapply")" -eq 8

for pass in before after; do
  for login in preview_pr42_app preview_pr43_app; do
    docker exec -e PGPASSWORD="$ATLAS_RUNTIME_PASSWORD" "$container" \
      psql -h 127.0.0.1 -U "$login" -d atlas -v ON_ERROR_STOP=1 -c 'SELECT current_user'
  done
  if [ "$pass" = before ]; then
    atlas schema apply --env roles --config "$apply_config" --auto-approve
  fi
done
echo 'Role policy, scope rejection, isolation and repeated-login checks passed'
