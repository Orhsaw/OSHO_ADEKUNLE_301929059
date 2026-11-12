-- =====================================================================
-- Portfolio 2 — indexes.sql
-- Analytical indexes added AFTER the BEFORE measurements so the
-- before/after EXPLAIN comparison is honest.
--   sudo runuser -u postgres -- psql -d sweetcrust -f indexes.sql
--
-- Q1, Q3, Q5, Q7 read a short window of due dates; Q2 reads the last 90
-- days of order dates. Q4 and Q6 aggregate the WHOLE table, so no index
-- can beat a sequential scan there (see before_after_table.md).
-- =====================================================================

\echo '==> Adding analytical indexes...'

-- Q1, Q3, Q5, Q7: range on due_date; INCLUDE makes the index covering.
CREATE INDEX IF NOT EXISTS idx_order_due_date_cover
    ON cake_order(due_date) INCLUDE (branch_id, tiers, status, unit_price_ngn);

-- Q2: range on order_date, grouped by cake type.
CREATE INDEX IF NOT EXISTS idx_order_order_date_cover
    ON cake_order(order_date) INCLUDE (cake_type_id);

-- Q5: deposits joined to orders.
CREATE INDEX IF NOT EXISTS idx_payment_order_kind
    ON payment(order_id, kind) INCLUDE (amount_ngn);

-- VACUUM sets the visibility map so index-only scans can work, and ANALYZE
-- refreshes statistics so the AFTER plan is reproducible.
VACUUM (ANALYZE) cake_order;
VACUUM (ANALYZE) payment;
ANALYZE order_flavour;
ANALYZE daily_capacity;

\echo '==> Done. Now run explain_after.sql to capture the improved plans.'
