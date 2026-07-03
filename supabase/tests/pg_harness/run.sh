#!/usr/bin/env bash
# Boots a throwaway local Postgres cluster, applies the Supabase stub + the REAL
# migrations, then runs the RLS/gate security tests. Exits nonzero on any failure.
#
# Requires a local Postgres install (initdb/pg_ctl/psql). Finds PG 16 by default.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MIG="$HERE/../../migrations"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
export PATH="$PGBIN:$PATH"

WORK="$(mktemp -d)"
DATADIR="$WORK/data"
SOCK="$WORK/sock"
mkdir -p "$SOCK"

cleanup() {
  pg_ctl -D "$DATADIR" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "== initdb =="
initdb -D "$DATADIR" -U postgres --auth=trust >/dev/null

echo "== start =="
pg_ctl -D "$DATADIR" -o "-c listen_addresses='' -k $SOCK" -w start >/dev/null

export PGHOST="$SOCK"
export PGUSER=postgres
export PGDATABASE=postgres
PSQL="psql -v ON_ERROR_STOP=1 -q"

echo "== stub =="
$PSQL -f "$HERE/00_supabase_stub.sql"

echo "== migrations =="
for f in "$MIG"/0001_init.sql "$MIG"/0002_rls.sql "$MIG"/0003_functions.sql; do
  echo "  applying $(basename "$f")"
  $PSQL -f "$f"
done

echo "== grants (mirror Supabase defaults) =="
$PSQL -f "$HERE/01_grants.sql"

echo "== RLS / gate security tests =="
LOG="$WORK/tests.out"
set +e
psql -v ON_ERROR_STOP=1 -f "$HERE/02_rls_tests.sql" >"$LOG" 2>&1
CODE=$?
set -e
grep -E "PASS|ASSERT FAIL|SECURITY FAIL|ALL RLS|ERROR|====" "$LOG" || true
if [ "$CODE" -ne 0 ]; then
  echo "RUNNER: security tests FAILED (exit $CODE)"
  exit "$CODE"
fi
echo "RUNNER: all security tests passed (exit 0)"
