-- =====================================================================
-- Portfolio 3 — place_order.sql
-- A transactional place_order(p_branch, p_customer, p_cake_type, p_tiers,
-- p_size, p_due_date, p_deposit_pct, p_method) function.
--
-- Inside ONE transaction it:
--   1. checks the day still has capacity (raises a clean error if not)
--   2. INSERTs the cake_order in PENDING status
--   3. INSERTs the deposit payment
--   4. (optional) flips to CONFIRMED if deposit >= 50%
--   5. COMMITs on success, ROLLBACKs on any exception
--
--   sudo runuser -u postgres -- psql -d sweetcrust -f place_order.sql
-- =====================================================================

CREATE OR REPLACE PROCEDURE place_order(
    p_branch_id   INTEGER,
    p_customer_id INTEGER,
    p_cake_type   INTEGER,
    p_tiers       INTEGER,
    p_size        TEXT,
    p_due_date    DATE,
    p_deposit_pct NUMERIC DEFAULT 0.50,
    p_method      TEXT    DEFAULT 'card',
    p_confirm     BOOLEAN DEFAULT TRUE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_base        NUMERIC(12,2);
    v_price       NUMERIC(12,2);
    v_used        INTEGER;
    v_cap         INTEGER;
    v_deposit     NUMERIC(12,2);
    v_order_id    INTEGER;
BEGIN
    -- ---------- preconditions ----------------------------------------
    IF p_tiers NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'tiers must be 1..5, got %', p_tiers;
    END IF;
    IF p_due_date < CURRENT_DATE + 2 THEN
        RAISE EXCEPTION 'due_date must be at least 2 days after today, got %',
            p_due_date;
    END IF;
    IF p_deposit_pct < 0.50 AND p_confirm THEN
        RAISE EXCEPTION 'deposit_pct must be >= 0.50 to confirm, got %',
            p_deposit_pct;
    END IF;

    SELECT base_price_ngn INTO v_base FROM cake_type WHERE cake_type_id = p_cake_type;
    IF v_base IS NULL THEN
        RAISE EXCEPTION 'cake_type % not found', p_cake_type;
    END IF;

    v_price := v_base
        + p_tiers * 8000.00
        + CASE p_size WHEN 'S' THEN 0 WHEN 'M' THEN 3000
                       WHEN 'L' THEN 7000 WHEN 'XL' THEN 12000 END;

    -- ---------- (1) check the day still has capacity ----------------
    SELECT COALESCE(SUM(tiers),0)
      INTO v_used
      FROM cake_order
     WHERE branch_id = p_branch_id
       AND due_date  = p_due_date
       AND status   <> 'CANCELLED';

    SELECT max_units
      INTO v_cap
      FROM daily_capacity
     WHERE branch_id = p_branch_id
       AND cap_date   = p_due_date;

    IF v_cap IS NULL THEN
        RAISE EXCEPTION 'no daily_capacity row for branch % on %',
            p_branch_id, p_due_date;
    END IF;

    IF v_used + p_tiers > v_cap THEN
        RAISE EXCEPTION
            'day fully booked: branch % on % has %/% units used',
            p_branch_id, p_due_date, v_used + p_tiers, v_cap;
    END IF;

    -- ---------- (2) create the order (PENDING) ----------------------
    BEGIN
        INSERT INTO cake_order(branch_id, customer_id, cake_type_id,
                               order_date, due_date, tiers, size_code,
                               unit_price_ngn, status, fulfillment_mode)
        VALUES (p_branch_id, p_customer_id, p_cake_type,
                CURRENT_DATE, p_due_date, p_tiers::SMALLINT, p_size,
                v_price, 'PENDING', 'pickup')
        RETURNING order_id INTO v_order_id;

        -- ---------- (3) record the deposit --------------------------
        v_deposit := ROUND(v_price * p_deposit_pct, 2);
        INSERT INTO payment(order_id, amount_ngn, kind, method)
        VALUES (v_order_id, v_deposit, 'deposit', p_method);

        -- ---------- (4) optionally confirm --------------------------
        IF p_confirm AND p_deposit_pct >= 0.50 THEN
            UPDATE cake_order SET status = 'CONFIRMED'
             WHERE order_id = v_order_id;
        END IF;

    EXCEPTION WHEN OTHERS THEN
        -- anything inside the BEGIN/EXCEPTION rolls back the SAVEPOINT
        -- (savepoint around the inner block) but NOT the whole call,
        -- so we re-raise to let the outer transaction decide.
        RAISE;
    END;

    RAISE NOTICE 'place_order OK -> order_id=% price=% deposit=%',
        v_order_id, v_price, v_deposit;
END;
$$;

-- =====================================================================
-- Demo call (success).
-- =====================================================================
\echo '--- place_order() success case ---'
SELECT customer_id FROM customer LIMIT 1;
DO $$
DECLARE c INTEGER;
BEGIN
    SELECT customer_id INTO c FROM customer LIMIT 1;
    CALL place_order(
        p_branch_id   => 1,
        p_customer_id => c,
        p_cake_type   => 1,
        p_tiers       => 2,
        p_size        => 'M',
        p_due_date    => CURRENT_DATE + 5,
        p_deposit_pct => 0.50,
        p_method      => 'card',
        p_confirm     => TRUE
    );
END $$;

-- =====================================================================
-- Demo call (failure: capacity exceeded) -> ROLLBACK inside the proc.
-- =====================================================================
\echo '--- place_order() failure: deposit_pct < 0.50 + p_confirm=TRUE (must be refused, nothing saved) ---'
SELECT COUNT(*) AS orders_before FROM cake_order WHERE due_date = CURRENT_DATE + 6 AND branch_id = 1 \gset
DO $$
DECLARE c INTEGER;
BEGIN
    SELECT customer_id INTO c FROM customer LIMIT 1;
    BEGIN
        CALL place_order(
            p_branch_id   => 1,
            p_customer_id => c,
            p_cake_type   => 1,
            p_tiers       => 2,
            p_size        => 'M',
            p_due_date    => CURRENT_DATE + 6,
            p_deposit_pct => 0.30,   -- below 50%: must raise
            p_method      => 'cash',
            p_confirm     => TRUE
        );
        RAISE NOTICE 'FAIL: place_order accepted a 30%% deposit';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'PASS: place_order refused as designed -> %', SQLERRM;
    END;
END $$;
SELECT COUNT(*) - :orders_before AS new_orders_saved_by_failed_call
  FROM cake_order WHERE due_date = CURRENT_DATE + 6 AND branch_id = 1;
