#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${FABRIC_TEST_IMAGE:-fabric-db:test}"
CONTAINER="${FABRIC_TEST_CONTAINER:-fabric-db-test}"
VOLUME="${FABRIC_TEST_VOLUME:-fabric-db-test-data}"
PORT="${FABRIC_TEST_PORT:-18000}"
USER="${SURREAL_USER:-root}"
PASS="${SURREAL_PASS:-root}"
NS="${SURREAL_NAMESPACE:-fabric_test}"
DB="${SURREAL_DATABASE:-fabric_test}"
KEEP="${FABRIC_TEST_KEEP:-0}"

cleanup() {
  if [[ "$KEEP" != "1" ]]; then
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    docker volume rm "$VOLUME" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

log() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nFAIL: %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null || fail "docker is required"
command -v curl >/dev/null || fail "curl is required"
docker info >/dev/null 2>&1 || fail "Docker daemon is not available"

cd "$ROOT_DIR"

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker volume rm "$VOLUME" >/dev/null 2>&1 || true

log "Building the production fabric.db image"
docker build -t "$IMAGE" .

log "Starting fabric.db on localhost:$PORT"
docker volume create "$VOLUME" >/dev/null
docker run -d \
  --name "$CONTAINER" \
  -p "${PORT}:8000" \
  -v "${VOLUME}:/data" \
  "$IMAGE" >/dev/null

log "Waiting for SurrealDB health"
for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null || fail "database did not become healthy"

sql() {
  docker exec -i "$CONTAINER" /surreal sql \
    --endpoint http://127.0.0.1:8000 \
    --username "$USER" \
    --password "$PASS" \
    --namespace "$NS" \
    --database "$DB" \
    --hide-welcome
}

import_file() {
  local path="$1"
  docker exec "$CONTAINER" /surreal import \
    --endpoint http://127.0.0.1:8000 \
    --username "$USER" \
    --password "$PASS" \
    --namespace "$NS" \
    --database "$DB" \
    "$path"
}

log "Loading schema"
import_file /fabric-db/surrealdb/schema.surql

log "Loading Fabric functions"
import_file /fabric-db/surrealdb/functions.surql

log "Checking schema registration"
INFO_OUT="$(printf 'INFO FOR DB;\n' | sql)"
for table in tenant actor agent tool policy approval event decision provenance desired_state observed_state drift; do
  grep -q "$table" <<<"$INFO_OUT" || fail "missing schema table: $table"
done

log "Running governed-state acceptance scenario"
docker cp tests/acceptance.surql "$CONTAINER:/tmp/fabric-acceptance.surql"
ACCEPTANCE_OUT="$(docker exec "$CONTAINER" /surreal import \
  --endpoint http://127.0.0.1:8000 \
  --username "$USER" \
  --password "$PASS" \
  --namespace "$NS" \
  --database "$DB" \
  /tmp/fabric-acceptance.surql 2>&1)"
printf '%s\n' "$ACCEPTANCE_OUT"

# Imports are primarily syntax/execution validation. Verify state independently.
CHECK_OUT="$(cat <<'SQL' | sql
SELECT * FROM tenant:test;
SELECT * FROM actor:test;
SELECT * FROM agent:test;
SELECT * FROM policy:test;
SELECT * FROM approval:test;
SELECT * FROM decision:test;
SELECT * FROM event:test;
SELECT * FROM provenance:test;
SELECT * FROM desired_state:test;
SELECT * FROM observed_state:test;
SELECT * FROM drift:test;
RETURN fn::event_type("agent", "execute");
RETURN fn::risk_weight("critical");
RETURN [event:test.payload.decision, decision:test.context.test, decision:test.selected_option.name, decision:test.policy_result.policy, decision:test.outcome.status, desired_state:test.spec.replicas, observed_state:test.state.replicas, drift:test.diff.field];
SQL
)"

grep -q 'Fabric Test Tenant' <<<"$CHECK_OUT" || fail "tenant fixture missing"
grep -q 'Acceptance Agent' <<<"$CHECK_OUT" || fail "agent fixture missing"
grep -q 'Allow Acceptance Execution' <<<"$CHECK_OUT" || fail "policy fixture missing"
grep -q 'approved' <<<"$CHECK_OUT" || fail "approval/decision chain missing"
grep -q 'agent.execute' <<<"$CHECK_OUT" || fail "event helper or event fixture failed"
grep -q 'acceptance-suite' <<<"$CHECK_OUT" || fail "provenance fixture missing"
grep -q 'replicas' <<<"$CHECK_OUT" || fail "desired/observed state fixture missing"
grep -q 'open' <<<"$CHECK_OUT" || fail "drift fixture missing"
grep -q '100' <<<"$CHECK_OUT" || fail "risk weighting helper failed"
grep -qF "['decision:test', true, 'execute', 'policy:test', 'approved', 1, 0, 'replicas']" <<<"$CHECK_OUT" || fail "nested object fields were not kept"

log "Testing persisted state across restart"
docker restart "$CONTAINER" >/dev/null
for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null || fail "database did not recover after restart"

PERSIST_OUT="$(printf 'SELECT * FROM tenant:test; SELECT * FROM drift:test;\n' | sql)"
grep -q 'Fabric Test Tenant' <<<"$PERSIST_OUT" || fail "tenant state was not persisted"
grep -q 'Acceptance Agent\|agent:test\|replicas' <<<"$PERSIST_OUT" || fail "governed state was not persisted"

log "PASS: fabric.db image, schema, governance fixture, helpers, drift state, and persistence are healthy"
if [[ "$KEEP" == "1" ]]; then
  printf 'Container kept: %s (http://127.0.0.1:%s)\n' "$CONTAINER" "$PORT"
fi
