-- =====================================================================
-- Portfolio 5 — partitioning.sql
-- Convert cake_order into a RANGE partitioned table on due_date month.
--
-- Run inside the dedicated sweetcrust_p5 database (created by setup.sh):
--   sudo runuser -u postgres -- psql -d sweetcrust_p5 -f partitioning.sql
--
-- Steps:
--   1. Create the partitioned parent cake_order (same columns as P1).
--   2. Create monthly partitions covering the data (730 days of history plus
--      the next 3 months), plus a DEFAULT partition for safety.
--   3. Copy the real P1 data (same SweetCrust case study) from the sweetcrust
--      database with \copy ... FROM PROGRAM (no postgres_fdw, no TCP). Run
--      Portfolio 1 first so there is data to copy.
--   4. Demonstrate partition pruning: a query filtered on a single month
--      only scans that one partition.
-- =====================================================================

\set ON_ERROR_STOP on

-- The decorator EXCLUDE constraint needs btree_gist in THIS database too.
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Clean slate
DROP TABLE IF EXISTS decorator_assignment CASCADE;
DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS order_flavour CASCADE;
DROP TABLE IF EXISTS cake_order CASCADE;
DROP TABLE IF EXISTS flavour CASCADE;
DROP TABLE IF EXISTS cake_type CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS daily_capacity CASCADE;
DROP TABLE IF EXISTS branch CASCADE;

-- 1. Reference tables (same as Portfolio 1 schema, abbreviated)
CREATE TABLE branch (
    branch_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL, city TEXT NOT NULL, address TEXT NOT NULL,
    UNIQUE (name, city)
);
CREATE TABLE daily_capacity (
    branch_id INTEGER NOT NULL REFERENCES branch(branch_id) ON DELETE CASCADE,
    cap_date DATE NOT NULL,
    max_units INTEGER NOT NULL CHECK (max_units > 0),
    PRIMARY KEY (branch_id, cap_date)
);
CREATE TABLE customer (
    customer_id SERIAL PRIMARY KEY,
    first_name TEXT NOT NULL, last_name TEXT NOT NULL,
    phone TEXT NOT NULL, email TEXT, city TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE cake_type (
    cake_type_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    base_price_ngn NUMERIC(12,2) NOT NULL CHECK (base_price_ngn > 0)
);
CREATE TABLE flavour (
    flavour_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    surcharge_ngn NUMERIC(12,2) NOT NULL DEFAULT 0
);

-- 2. PARTITIONED cake_order parent
CREATE TABLE cake_order (
    order_id          BIGSERIAL,
    branch_id         INTEGER  NOT NULL REFERENCES branch(branch_id),
    customer_id       INTEGER  NOT NULL REFERENCES customer(customer_id),
    cake_type_id      INTEGER  NOT NULL REFERENCES cake_type(cake_type_id),
    order_date        DATE     NOT NULL,
    due_date          DATE     NOT NULL,
    tiers             SMALLINT NOT NULL CHECK (tiers BETWEEN 1 AND 5),
    size_code         TEXT     NOT NULL CHECK (size_code IN ('S','M','L','XL')),
    unit_price_ngn    NUMERIC(12,2) NOT NULL CHECK (unit_price_ngn > 0),
    status            TEXT     NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING','CONFIRMED','BAKING','DECORATING','READY','COLLECTED','DELIVERED','CANCELLED')),
    fulfillment_mode  TEXT     NOT NULL DEFAULT 'pickup'
                      CHECK (fulfillment_mode IN ('pickup','delivery')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_due_after_order CHECK (due_date >= order_date + INTERVAL '2 days'),
    PRIMARY KEY (order_id, due_date)            -- partition key must be in PK
) PARTITION BY RANGE (due_date);

-- 3. Create monthly partitions covering the data: from the month of
--    (today - 730 days) up to 3 months ahead. Each partition covers one
--    calendar month, with the boundary on the first day of the next month.
DO $$
DECLARE
    start_month DATE := date_trunc('month', CURRENT_DATE - 730)::date;
    p_start     DATE;
    p_end       DATE;
    p_name      TEXT;
BEGIN
    FOR i IN 0..28 LOOP
        p_start := (start_month + (i || ' months')::interval)::date;
        p_end   := (start_month + ((i+1) || ' months')::interval)::date;
        p_name  := 'cake_order_' || to_char(p_start, 'YYYY_MM');
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF cake_order FOR VALUES FROM (%L) TO (%L)',
            p_name, p_start, p_end);
    END LOOP;
END $$;

-- Default partition for any out-of-range date (defensive; should be empty)
CREATE TABLE cake_order_default PARTITION OF cake_order DEFAULT;

-- Child tables. Their foreign keys to the partitioned parent must include
-- the partition key, so they carry due_date as well as order_id.
CREATE TABLE order_flavour (
    order_id   BIGINT  NOT NULL,
    due_date   DATE    NOT NULL,
    flavour_id INTEGER NOT NULL REFERENCES flavour(flavour_id),
    tier_no    SMALLINT NOT NULL CHECK (tier_no BETWEEN 1 AND 5),
    FOREIGN KEY (order_id, due_date) REFERENCES cake_order(order_id, due_date) ON DELETE CASCADE,
    PRIMARY KEY (order_id, flavour_id, tier_no)
);

CREATE TABLE payment (
    payment_id  BIGSERIAL PRIMARY KEY,
    order_id    BIGINT NOT NULL,
    due_date    DATE NOT NULL,
    amount_ngn  NUMERIC(12,2) NOT NULL CHECK (amount_ngn > 0),
    paid_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    kind        TEXT NOT NULL CHECK (kind IN ('deposit','balance')),
    method      TEXT NOT NULL CHECK (method IN ('card','transfer','cash','pos')),
    FOREIGN KEY (order_id, due_date) REFERENCES cake_order(order_id, due_date) ON DELETE CASCADE
);

CREATE TABLE decorator_assignment (
    assignment_id SERIAL PRIMARY KEY,
    decorator_id  INTEGER NOT NULL,
    branch_id     INTEGER NOT NULL REFERENCES branch(branch_id),
    order_id      BIGINT NOT NULL,
    due_date      DATE NOT NULL,
    decorating_window TSTZRANGE NOT NULL,
    status        TEXT NOT NULL DEFAULT 'ASSIGNED'
                  CHECK (status IN ('ASSIGNED','IN_PROGRESS','DONE','CANCELLED')),
    FOREIGN KEY (order_id, due_date) REFERENCES cake_order(order_id, due_date),
    CONSTRAINT exc_no_overlap_per_decorator
        EXCLUDE USING gist (decorator_id WITH =, decorating_window WITH &&)
);

-- 4. Load the real P1 data (run Portfolio 1 first). Each \copy runs a COPY ... TO STDOUT
--    in the sweetcrust database and streams it into this one over the Unix socket.
\copy branch FROM PROGRAM 'psql -X -q -d sweetcrust -c "COPY branch TO STDOUT"'
\copy daily_capacity FROM PROGRAM 'psql -X -q -d sweetcrust -c "COPY daily_capacity TO STDOUT"'
\copy customer FROM PROGRAM 'psql -X -q -d sweetcrust -c "COPY customer TO STDOUT"'
\copy cake_type FROM PROGRAM 'psql -X -q -d sweetcrust -c "COPY cake_type TO STDOUT"'
\copy flavour FROM PROGRAM 'psql -X -q -d sweetcrust -c "COPY flavour TO STDOUT"'
\copy cake_order FROM PROGRAM 'psql -X -q -d sweetcrust -c "COPY cake_order TO STDOUT"'
\copy order_flavour FROM PROGRAM 'psql -X -q -d sweetcrust -c "COPY (SELECT f.order_id, o.due_date, f.flavour_id, f.tier_no FROM order_flavour f JOIN cake_order o USING (order_id)) TO STDOUT"'
\copy payment FROM PROGRAM 'psql -X -q -d sweetcrust -c "COPY (SELECT p.payment_id, p.order_id, o.due_date, p.amount_ngn, p.paid_at, p.kind, p.method FROM payment p JOIN cake_order o USING (order_id)) TO STDOUT"'
\copy decorator_assignment FROM PROGRAM 'psql -X -q -d sweetcrust -c "COPY (SELECT a.assignment_id, a.decorator_id, a.branch_id, a.order_id, o.due_date, a.decorating_window, a.status FROM decorator_assignment a JOIN cake_order o USING (order_id)) TO STDOUT"'

-- Keep the sequences ahead of the copied ids.
SELECT setval('branch_branch_id_seq',            (SELECT MAX(branch_id)     FROM branch));
SELECT setval('customer_customer_id_seq',        (SELECT MAX(customer_id)   FROM customer));
SELECT setval('cake_type_cake_type_id_seq',      (SELECT MAX(cake_type_id)  FROM cake_type));
SELECT setval('flavour_flavour_id_seq',          (SELECT MAX(flavour_id)    FROM flavour));
SELECT setval('cake_order_order_id_seq',         (SELECT MAX(order_id)      FROM cake_order));
SELECT setval('payment_payment_id_seq',          (SELECT MAX(payment_id)    FROM payment));
SELECT setval('decorator_assignment_assignment_id_seq', (SELECT MAX(assignment_id) FROM decorator_assignment));
ANALYZE;

\echo '--- Row counts copied from Portfolio 1 ---'
SELECT 'cake_order' AS tbl, COUNT(*) FROM cake_order
UNION ALL SELECT 'order_flavour', COUNT(*) FROM order_flavour
UNION ALL SELECT 'payment', COUNT(*) FROM payment
UNION ALL SELECT 'decorator_assignment', COUNT(*) FROM decorator_assignment;

-- 5. Verify partition pruning: this query should scan only ONE partition.
\echo '--- Partition pruning demo: only one partition is scanned ---'
EXPLAIN (COSTS OFF)
SELECT count(*) FROM cake_order
 WHERE due_date >= date_trunc('month', CURRENT_DATE)::date
   AND due_date <  (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month')::date;

-- 7. Show the partition list
\echo '--- Partitions created ---'
SELECT inhrelid::regclass AS partition
  FROM pg_inherits
 WHERE inhparent = 'cake_order'::regclass
 ORDER BY 1;

\echo '--- Row counts per partition (real counts) ---'
SELECT tableoid::regclass AS partition, COUNT(*) AS orders
  FROM cake_order
 GROUP BY 1
 ORDER BY 1;

\echo '--- DEFAULT partition must be empty (every row has a monthly partition) ---'
SELECT COUNT(*) AS rows_in_default_partition FROM cake_order_default;

\echo '--- Pruning with EXPLAIN ANALYZE: one month scans one partition ---'
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON)
SELECT count(*) FROM cake_order
 WHERE due_date >= date_trunc('month', CURRENT_DATE)::date
   AND due_date <  (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month')::date;

\echo '--- No pruning: same count over all 29 partitions (for comparison) ---'
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON)
SELECT count(*) FROM cake_order;
