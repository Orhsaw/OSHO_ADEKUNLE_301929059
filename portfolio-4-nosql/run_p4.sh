#!/usr/bin/env bash
# run_p4.sh — Portfolio 4 (MongoDB NoSQL) runner.
set -euo pipefail
cd "$(dirname "$0")"

MONGO="mongosh --quiet sweetcrust_designs"

# MongoDB must be running (a Codespace that slept stops it).
pgrep -x mongod >/dev/null || { mkdir -p "$HOME/mongo-data"; mongod --fork --dbpath "$HOME/mongo-data" --logpath "$HOME/mongod.log" --bind_ip 127.0.0.1 >/dev/null; sleep 3; }

echo "==> [1/4] Recreate designs collection with \$jsonSchema validator"
$MONGO mongo_schema_validation.js | tee schema_validation.log

echo
echo "==> [2/4] Bulk-insert 40,000 design documents"
$MONGO seed_designs.js | tee seed_designs.log

echo
echo "==> [3/4] Run aggregations"
$MONGO aggregations.js | tee aggregations.log

echo
echo "==> [4/4] COLLSCAN -> IXSCAN demo (run BEFORE / AFTER explain plans)"
$MONGO index_demo.js | tee index_demo.log

echo
echo "==> Portfolio 4 done. Evidence: schema_validation.log, seed_designs.log,"
echo "    aggregations.log, index_demo.log (all saved by this script)."
