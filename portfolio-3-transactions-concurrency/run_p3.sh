#!/usr/bin/env bash
# run_p3.sh — Portfolio 3 runner. Everything runs automatically, including the
# two-session race, isolation and deadlock demos (no second terminal needed).
set -euo pipefail
cd "$(dirname "$0")"

PSQL="sudo runuser -u postgres -- psql -d sweetcrust"

echo "==> [1/4] Compile the place_order() procedure + run its 2 demos"
$PSQL -f place_order.sql

echo
echo "==> [2/4] COMMIT / ROLLBACK / SAVEPOINT demos"
$PSQL -f commit_rollback.sql

echo
echo "==> [3/4] Isolation levels reference (single session)"
$PSQL -f isolation_levels.sql

echo
echo "==> [4/4] Two-session race, fixes, isolation and deadlock demos (real, automated)"
# postgres must be able to read the script, so run a copy from /tmp
cp run_race_demos.py /tmp/run_race_demos.py && chmod 644 /tmp/run_race_demos.py
( cd /tmp && sudo runuser -u postgres -- python3 /tmp/run_race_demos.py ) 2>&1 | tee race_demos_output.log

echo
echo "==> Portfolio 3 done. Evidence saved in race_demos_output.log"
