#!/usr/bin/env bash
# run_p2.sh — Portfolio 2 runner: baseline queries, EXPLAIN before,
# add indexes, EXPLAIN after, then the queries themselves.
set -euo pipefail
cd "$(dirname "$0")"

PSQL="sudo runuser -u postgres -- psql -d sweetcrust -v ON_ERROR_STOP=1"

echo "==> [1/4] EXPLAIN ANALYZE BEFORE indexes"
$PSQL -f explain_before.sql | tee explain_before.log

echo
echo "==> [2/4] Adding analytical indexes + ANALYZE"
$PSQL -f indexes.sql

echo
echo "==> [3/4] EXPLAIN ANALYZE AFTER indexes"
$PSQL -f explain_after.sql | tee explain_after.log

echo
echo "==> [4/4] Run the actual queries (with result rows)"
$PSQL -f queries.sql | tee queries.log

echo
echo "==> Portfolio 2 done."
echo "    1. Copy each EXPLAIN ANALYZE block from explain_before.log"
echo "       and explain_after.log into before_after_table.md"
echo "    2. Copy the query result rows from queries.log"
echo "    3. Screenshot the before/after Execution Time deltas"
echo "    4. Commit:"
echo "    git add portfolio-2-query-optimisation/ && git commit -m 'P2: queries + index optimisation EXPLAIN before/after'"
