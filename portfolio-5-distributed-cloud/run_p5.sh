#!/usr/bin/env bash
# run_p5.sh — Portfolio 5 (Distributed & Cloud Database) runner.
# Needs Portfolio 1 to have been run first (P5 copies its data).
set -euo pipefail
cd "$(dirname "$0")"

PSQL="sudo runuser -u postgres -- psql -X -d sweetcrust_p5 -v ON_ERROR_STOP=1"

echo "==> [1/2] partitioning.sql — partition cake_order by due_date month (real P1 data)"
$PSQL -f partitioning.sql 2>&1 | tee partitioning.log

echo
echo "==> [2/2] replication_demo.sh — streaming replica on port 5433, fully automated"
bash replication_demo.sh 2>&1 | tee replication_output.log

echo
echo "==> Portfolio 5 done. Evidence: partitioning.log and replication_output.log"
echo "    Architecture docs: cloud_architecture.md (NDPA 2023, in-country residency),"
echo "                       cap_tradeoffs.md (CP vs AP, sync vs async, RPO/RTO)"
