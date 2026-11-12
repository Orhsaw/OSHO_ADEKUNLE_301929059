-- =====================================================================
-- Portfolio 2 — explain_before.sql
-- Run BEFORE creating any extra indexes (the schema.sql indexes already
-- exist, but the analytical indexes used by these queries do not).
-- Run with:
--   sudo runuser -u postgres -- psql -d sweetcrust -f explain_before.sql
-- Each block prints EXPLAIN ANALYZE for the query (no result rows) so
-- you can paste the plan into before_after_table.md.
-- =====================================================================

\pset pager off

\echo '--- BEFORE: Q1 remaining capacity per branch, next 7 days ---'
EXPLAIN ANALYZE
SELECT  b.name AS branch,
        dc.cap_date,
        dc.max_units,
        dc.max_units - COALESCE(SUM(co.tiers),0) AS remaining_units
FROM    branch b
JOIN    daily_capacity dc ON dc.branch_id = b.branch_id
LEFT JOIN cake_order co
       ON co.branch_id = b.branch_id
      AND co.due_date   = dc.cap_date
      AND co.due_date   BETWEEN CURRENT_DATE AND CURRENT_DATE + 7
      AND co.status    <> 'CANCELLED'
WHERE   dc.cap_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7
GROUP BY b.name, dc.cap_date, dc.max_units
ORDER BY b.name, dc.cap_date;

\echo '--- BEFORE: Q2 orders per cake type per month, last 90 days ---'
EXPLAIN ANALYZE
SELECT  to_char(co.order_date,'YYYY-MM') AS yyyymm,
        ct.name                          AS cake_type,
        COUNT(*)                         AS orders
FROM    cake_order co
JOIN    cake_type  ct ON ct.cake_type_id = co.cake_type_id
WHERE   co.order_date >= CURRENT_DATE - 90
GROUP BY 1,2
ORDER BY 1,2;

\echo '--- BEFORE: Q3 revenue per branch, orders due in the last 30 days ---'
EXPLAIN ANALYZE
SELECT  b.name AS branch,
        SUM(p.amount_ngn) AS revenue_ngn
FROM    payment p
JOIN    cake_order co ON co.order_id = p.order_id
JOIN    branch     b  ON b.branch_id = co.branch_id
WHERE   co.status <> 'CANCELLED'
  AND   co.due_date BETWEEN CURRENT_DATE - 30 AND CURRENT_DATE
GROUP BY b.name
ORDER BY revenue_ngn DESC;

\echo '--- BEFORE: Q4 most popular flavours ---'
EXPLAIN ANALYZE
SELECT  f.name AS flavour,
        COUNT(*) AS tier_uses,
        COUNT(DISTINCT ofl.order_id) AS orders_using_it
FROM    order_flavour ofl
JOIN    flavour f ON f.flavour_id = ofl.flavour_id
GROUP BY f.name
ORDER BY tier_uses DESC;

\echo '--- BEFORE: Q5 average deposit percentage, orders due in the last 30 days ---'
EXPLAIN ANALYZE
SELECT  AVG(dep.amount_ngn / co.unit_price_ngn * 100) AS avg_deposit_pct
FROM    payment dep
JOIN    cake_order co ON co.order_id = dep.order_id
WHERE   dep.kind = 'deposit'
  AND   co.status <> 'CANCELLED'
  AND   co.due_date BETWEEN CURRENT_DATE - 30 AND CURRENT_DATE;

\echo '--- BEFORE: Q6 cancellation rate per branch ---'
EXPLAIN ANALYZE
SELECT  b.name AS branch,
        COUNT(*) FILTER (WHERE co.status='CANCELLED') AS cancelled,
        COUNT(*) AS total,
        ROUND(100.0 * COUNT(*) FILTER (WHERE co.status='CANCELLED')
              / NULLIF(COUNT(*),0),2) AS cancel_rate_pct
FROM    cake_order co
JOIN    branch b ON b.branch_id = co.branch_id
GROUP BY b.name
ORDER BY cancel_rate_pct DESC;
