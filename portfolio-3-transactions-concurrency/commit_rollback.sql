-- =====================================================================
-- Portfolio 3 — commit_rollback.sql
-- Demonstrates COMMIT and ROLLBACK at the psql level.
--
-- Run twice:
--   sudo runuser -u postgres -- psql -d sweetcrust -f commit_rollback.sql
--
-- Each block writes data, then either commits or rolls back, then prints
-- the row count so you can see the difference.
-- =====================================================================

\pset pager off

-- =====================================================================
-- Scenario A: COMMIT
-- Insert one order + deposit, COMMIT, then verify the row is still there.
-- =====================================================================
\echo '--- A) COMMIT path ---'
BEGIN;
    INSERT INTO cake_order(branch_id, customer_id, cake_type_id,
                           order_date, due_date, tiers, size_code,
                           unit_price_ngn, status, fulfillment_mode)
    SELECT 1, customer_id, 1, CURRENT_DATE, CURRENT_DATE + 7, 1, 'S',
           18000, 'PENDING', 'pickup'
      FROM customer LIMIT 1
    RETURNING order_id \gset

    INSERT INTO payment(order_id, amount_ngn, kind, method)
    VALUES (:order_id, 9000, 'deposit', 'card');
COMMIT;

\echo '--- after COMMIT: order should be visible ---'
SELECT order_id, status FROM cake_order WHERE order_id = :order_id;

-- =====================================================================
-- Scenario B: ROLLBACK — a failed deposit cancels the order.
-- Simulate: insert order, attempt deposit, deposit raises (e.g. amount=0
-- violates CHECK), the exception rolls back the whole transaction so the
-- order is NOT persisted.
-- =====================================================================
\echo '--- B) ROLLBACK path (failed deposit cancels the order) ---'
BEGIN;
    INSERT INTO cake_order(branch_id, customer_id, cake_type_id,
                           order_date, due_date, tiers, size_code,
                           unit_price_ngn, status, fulfillment_mode)
    SELECT 1, customer_id, 1, CURRENT_DATE, CURRENT_DATE + 8, 1, 'S',
           18000, 'PENDING', 'pickup'
      FROM customer LIMIT 1
    RETURNING order_id AS rollback_order_id \gset

    \echo '--- inserted (uncommitted) order_id = ' :rollback_order_id

    -- attempt the deposit; this amount violates CHECK(amount_ngn > 0)
    INSERT INTO payment(order_id, amount_ngn, kind, method)
    VALUES (:rollback_order_id, 0, 'deposit', 'card');
COMMIT;  -- never reached

\echo '--- after ROLLBACK: order should NOT be visible ---'
SELECT COUNT(*) AS rows_after_rollback
  FROM cake_order WHERE order_id = :rollback_order_id;

-- =====================================================================
-- Scenario C: same idea but with an explicit SAVEPOINT.
-- The deposit fails, rolls back to savepoint, the order survives.
-- =====================================================================
\echo '--- C) SAVEPOINT path: order survives a failed deposit ---'
BEGIN;
    INSERT INTO cake_order(branch_id, customer_id, cake_type_id,
                           order_date, due_date, tiers, size_code,
                           unit_price_ngn, status, fulfillment_mode)
    SELECT 1, customer_id, 1, CURRENT_DATE, CURRENT_DATE + 9, 1, 'S',
           18000, 'PENDING', 'pickup'
      FROM customer LIMIT 1
    RETURNING order_id AS savepoint_order_id \gset

    SAVEPOINT sp_deposit;
    -- first deposit fails (bad amount)
    INSERT INTO payment(order_id, amount_ngn, kind, method)
    VALUES (:savepoint_order_id, 0, 'deposit', 'card');
    ROLLBACK TO sp_deposit;

    -- retry with a valid deposit
    INSERT INTO payment(order_id, amount_ngn, kind, method)
    VALUES (:savepoint_order_id, 9000, 'deposit', 'card');

COMMIT;

\echo '--- after COMMIT: order + deposit both visible ---'
SELECT order_id, status FROM cake_order WHERE order_id = :savepoint_order_id;
SELECT payment_id, amount_ngn, kind FROM payment WHERE order_id = :savepoint_order_id;
