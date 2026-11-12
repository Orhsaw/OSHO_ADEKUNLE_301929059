-- =====================================================================
-- Portfolio 1 — schema.sql
-- SweetCrust Bakery — relational schema (3NF), 9 tables.
-- Run inside the sweetcrust database after setup.sh.
--
--   sudo runuser -u postgres -- psql -d sweetcrust -f portfolio-1-database-design/schema.sql
-- =====================================================================

DROP TABLE IF EXISTS decorator_assignment CASCADE;
DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS order_flavour CASCADE;
DROP TABLE IF EXISTS cake_order CASCADE;
DROP TABLE IF EXISTS flavour CASCADE;
DROP TABLE IF EXISTS cake_type CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP TABLE IF EXISTS daily_capacity CASCADE;
DROP TABLE IF EXISTS branch CASCADE;

-- ---- 1. branch ------------------------------------------------------
CREATE TABLE branch (
    branch_id  SERIAL PRIMARY KEY,
    name       TEXT        NOT NULL,
    city       TEXT        NOT NULL,
    address    TEXT        NOT NULL,
    UNIQUE (name, city)
);

-- ---- 2. daily_capacity (composite PK, per branch per date) ----------
CREATE TABLE daily_capacity (
    branch_id  INTEGER  NOT NULL REFERENCES branch(branch_id) ON DELETE CASCADE,
    cap_date   DATE     NOT NULL,
    max_units  INTEGER  NOT NULL CHECK (max_units > 0),
    PRIMARY KEY (branch_id, cap_date)
);

-- ---- 3. customer ----------------------------------------------------
CREATE TABLE customer (
    customer_id  SERIAL PRIMARY KEY,
    first_name   TEXT NOT NULL,
    last_name    TEXT NOT NULL,
    phone        TEXT NOT NULL,
    email        TEXT,
    city         TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---- 4. cake_type ---------------------------------------------------
CREATE TABLE cake_type (
    cake_type_id     SERIAL PRIMARY KEY,
    name             TEXT NOT NULL UNIQUE,   -- birthday|wedding|graduation|corporate
    base_price_ngn   NUMERIC(12,2) NOT NULL CHECK (base_price_ngn > 0)
);

-- ---- 5. flavour -----------------------------------------------------
CREATE TABLE flavour (
    flavour_id      SERIAL PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    surcharge_ngn   NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (surcharge_ngn >= 0)
);

-- ---- 6. cake_order --------------------------------------------------
-- C3: due_date >= order_date + 2 days
-- C5: tiers 1..5, unit_price > 0
CREATE TABLE cake_order (
    order_id          SERIAL PRIMARY KEY,
    branch_id         INTEGER  NOT NULL REFERENCES branch(branch_id),
    customer_id       INTEGER  NOT NULL REFERENCES customer(customer_id),
    cake_type_id      INTEGER  NOT NULL REFERENCES cake_type(cake_type_id),
    order_date        DATE     NOT NULL DEFAULT CURRENT_DATE,
    due_date          DATE     NOT NULL,
    tiers             SMALLINT NOT NULL CHECK (tiers BETWEEN 1 AND 5),
    size_code         TEXT     NOT NULL CHECK (size_code IN ('S','M','L','XL')),
    unit_price_ngn    NUMERIC(12,2) NOT NULL CHECK (unit_price_ngn > 0),
    status            TEXT     NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING','CONFIRMED','BAKING','DECORATING','READY','COLLECTED','DELIVERED','CANCELLED')),
    fulfillment_mode  TEXT     NOT NULL DEFAULT 'pickup'
                      CHECK (fulfillment_mode IN ('pickup','delivery')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_due_after_order CHECK (due_date >= order_date + INTERVAL '2 days')
);

-- Partition hook for Portfolio 5 (kept here so P1 imports cleanly; the
-- partition conversion itself is done in Portfolio 5/partitioning.sql).
-- For Portfolio 1 the table stays unpartitioned.

-- ---- 7. order_flavour (M:N, one flavour per tier) --------------------
CREATE TABLE order_flavour (
    order_id     INTEGER NOT NULL REFERENCES cake_order(order_id) ON DELETE CASCADE,
    flavour_id   INTEGER NOT NULL REFERENCES flavour(flavour_id),
    tier_no      SMALLINT NOT NULL CHECK (tier_no BETWEEN 1 AND 5),
    PRIMARY KEY (order_id, flavour_id, tier_no)
);

-- ---- 8. payment -----------------------------------------------------
CREATE TABLE payment (
    payment_id   SERIAL PRIMARY KEY,
    order_id     INTEGER  NOT NULL REFERENCES cake_order(order_id) ON DELETE CASCADE,
    amount_ngn   NUMERIC(12,2) NOT NULL CHECK (amount_ngn > 0),
    paid_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    kind         TEXT NOT NULL CHECK (kind IN ('deposit','balance')),
    method       TEXT NOT NULL CHECK (method IN ('card','transfer','cash','pos'))
);

-- ---- 9. decorator_assignment (EXCLUDE on tstzrange, btree_gist) ------
-- C2: a decorator cannot be on two overlapping decorating windows.
CREATE TABLE decorator_assignment (
    assignment_id       SERIAL PRIMARY KEY,
    decorator_id        INTEGER  NOT NULL,
    branch_id           INTEGER  NOT NULL REFERENCES branch(branch_id),
    order_id            INTEGER  NOT NULL REFERENCES cake_order(order_id),
    decorating_window   TSTZRANGE NOT NULL,
    status              TEXT NOT NULL DEFAULT 'ASSIGNED'
                        CHECK (status IN ('ASSIGNED','IN_PROGRESS','DONE','CANCELLED')),
    CONSTRAINT exc_no_overlap_per_decorator
        EXCLUDE USING gist (decorator_id WITH =, decorating_window WITH &&)
);

-- =====================================================================
-- Indexes that mirror the foreign keys + the obvious hot lookups.
-- The full Portfolio 2 indexing experiment is in
-- portfolio-2-query-optimisation/indexes.sql, applied AFTER measuring
-- the baseline so the "before" numbers are honest.
-- =====================================================================
CREATE INDEX idx_cake_order_branch_due        ON cake_order(branch_id, due_date);
CREATE INDEX idx_cake_order_customer          ON cake_order(customer_id);
CREATE INDEX idx_cake_order_cake_type         ON cake_order(cake_type_id);
CREATE INDEX idx_cake_order_status            ON cake_order(status);
CREATE INDEX idx_payment_order                ON payment(order_id);
CREATE INDEX idx_order_flavour_flavour        ON order_flavour(flavour_id);
CREATE INDEX idx_decorator_assignment_decorator ON decorator_assignment(decorator_id);
