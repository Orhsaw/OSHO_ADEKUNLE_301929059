-- =====================================================================
-- Portfolio 3 — isolation_levels.sql
-- Single-session reference: shows the isolation level each transaction
-- really runs at in PostgreSQL. The live two-session demonstrations
-- (non-repeatable read, frozen snapshot, serialization failure) are in
-- run_race_demos.py, Parts 3, 4 and 5, and are saved to
-- race_demos_output.log with real output.
--
--   sudo runuser -u postgres -- psql -d sweetcrust -f isolation_levels.sql
-- =====================================================================
\pset pager off

\echo '--- default isolation level of this server ---'
SHOW default_transaction_isolation;

\echo '--- READ UNCOMMITTED is accepted but behaves as READ COMMITTED in PostgreSQL ---'
BEGIN ISOLATION LEVEL READ UNCOMMITTED;
SHOW transaction_isolation;
COMMIT;

\echo '--- READ COMMITTED ---'
BEGIN ISOLATION LEVEL READ COMMITTED;
SHOW transaction_isolation;
COMMIT;

\echo '--- REPEATABLE READ ---'
BEGIN ISOLATION LEVEL REPEATABLE READ;
SHOW transaction_isolation;
COMMIT;

\echo '--- SERIALIZABLE ---'
BEGIN ISOLATION LEVEL SERIALIZABLE;
SHOW transaction_isolation;
COMMIT;

\echo 'Live demos of what these levels do: run_race_demos.py (Parts 3, 4, 5).'
