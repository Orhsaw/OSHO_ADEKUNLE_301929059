#!/usr/bin/env bash
# run_p1.sh — Portfolio 1 (Database Design & Modelling) runner.
set -euo pipefail
cd "$(dirname "$0")"

PSQL="sudo runuser -u postgres -- psql -d sweetcrust -v ON_ERROR_STOP=1"

echo "==> [1/5] schema.sql (9 tables, 3NF, all constraints)"
$PSQL -f schema.sql

echo "==> [2/5] constraints.sql (triggers + EXCLUDE + FSM)"
$PSQL -f constraints.sql

echo "==> [3/5] seed_data.sql (branches, cake_types, flavours, 730-day capacity)"
$PSQL -f seed_data.sql

echo "==> [4/5] bulk_generator.sql (50k+ orders over 2 years, NGN prices, peaks)"
$PSQL -f bulk_generator.sql

echo "==> [5/5] constraint_tests.sql (8 tests; each must be refused by the database)"
# Tests catch their own errors and print PASS or FAIL.
sudo runuser -u postgres -- psql -d sweetcrust -f constraint_tests.sql

echo
echo "==> Portfolio 1 done."
echo "    Next: capture the bulk_generator output table + the 8 constraint"
echo "    test failures into a screenshot, then commit:"
echo "    git add portfolio-1-database-design/ && git commit -m 'P1: schema, triggers, bulk data, constraint tests'"
echo
echo "    To view ER + 3NF: cat er_diagram.md 3nf_notes.md"
