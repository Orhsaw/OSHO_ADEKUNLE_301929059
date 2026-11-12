-- =====================================================================
-- Portfolio 1 — constraints.sql (triggers + CHECK + EXCLUDE)
-- SweetCrust Bakery.
--   sudo runuser -u postgres -- psql -d sweetcrust -f constraints.sql
-- =====================================================================

-- ===== Helper: compute the number of cake units a single order uses ===
-- 1 tier = 1 unit, so a 3-tier cake consumes 3 units of branch capacity.
CREATE OR REPLACE FUNCTION cake_units(p_tiers SMALLINT)
RETURNS INTEGER LANGUAGE SQL IMMUTABLE AS $$
    SELECT p_tiers::INTEGER;
$$;

-- ===== C1 trigger: a branch can't exceed daily_capacity on due_date ===
CREATE OR REPLACE FUNCTION fn_check_capacity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    used_units   INTEGER;
    max_units    INTEGER;
BEGIN
    SELECT COALESCE(SUM(cake_units(tiers)), 0)
      INTO used_units
      FROM cake_order
     WHERE branch_id = NEW.branch_id
       AND due_date   = NEW.due_date
       AND status    <> 'CANCELLED'
       AND order_id IS DISTINCT FROM NEW.order_id;   -- don't count this row twice on UPDATE

    SELECT dc.max_units
      INTO max_units
      FROM daily_capacity dc
     WHERE dc.branch_id = NEW.branch_id
       AND dc.cap_date  = NEW.due_date;

    -- Cancelling an order only frees capacity; never block it.
    IF NEW.status = 'CANCELLED' THEN
        RETURN NEW;
    END IF;

    IF max_units IS NULL THEN
        RAISE EXCEPTION 'No daily_capacity row for branch % on %',
            NEW.branch_id, NEW.due_date;
    END IF;

    IF used_units + cake_units(NEW.tiers) > max_units THEN
        RAISE EXCEPTION
            'Capacity exceeded: branch % on % would have %/% units used',
            NEW.branch_id, NEW.due_date,
            used_units + cake_units(NEW.tiers), max_units;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_capacity ON cake_order;
CREATE TRIGGER trg_check_capacity
    BEFORE INSERT OR UPDATE OF branch_id, due_date, tiers, status ON cake_order
    FOR EACH ROW EXECUTE FUNCTION fn_check_capacity();

-- ===== C4 trigger: deposit >= 50% before status can become CONFIRMED ===
CREATE OR REPLACE FUNCTION fn_deposit_before_confirm()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    paid_deposit NUMERIC(12,2);
BEGIN
    IF NEW.status = 'CONFIRMED' THEN
        SELECT COALESCE(SUM(amount_ngn), 0)
          INTO paid_deposit
          FROM payment
         WHERE order_id = NEW.order_id
           AND kind     = 'deposit';

        IF paid_deposit < (NEW.unit_price_ngn * 0.50) THEN
            RAISE EXCEPTION
                'Cannot confirm order %: deposit % is less than 50%% of %',
                NEW.order_id, paid_deposit, NEW.unit_price_ngn;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_deposit_before_confirm ON cake_order;
CREATE TRIGGER trg_deposit_before_confirm
    BEFORE UPDATE OF status ON cake_order
    FOR EACH ROW
    WHEN (NEW.status = 'CONFIRMED' AND OLD.status <> 'CONFIRMED')
    EXECUTE FUNCTION fn_deposit_before_confirm();

-- ===== C6 trigger: order status FSM ===
-- PENDING -> CONFIRMED -> BAKING -> DECORATING -> READY -> COLLECTED|DELIVERED
-- any non-terminal state -> CANCELLED (no resurrection)
CREATE OR REPLACE FUNCTION fn_status_fsm()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    valid_transitions TEXT[][] := ARRAY[
        ['PENDING','CONFIRMED'],
        ['PENDING','CANCELLED'],
        ['CONFIRMED','BAKING'],
        ['CONFIRMED','CANCELLED'],
        ['BAKING','DECORATING'],
        ['BAKING','CANCELLED'],
        ['DECORATING','READY'],
        ['DECORATING','CANCELLED'],
        ['READY','COLLECTED'],
        ['READY','DELIVERED']
    ];
    allowed BOOLEAN := FALSE;
BEGIN
    IF NEW.status = OLD.status THEN RETURN NEW; END IF;

    -- CANCELLED is terminal: cannot leave CANCELLED.
    IF OLD.status = 'CANCELLED' AND NEW.status <> 'CANCELLED' THEN
        RAISE EXCEPTION 'Order % is CANCELLED and cannot be revived to %',
            NEW.order_id, NEW.status;
    END IF;
    IF NEW.status = 'COLLECTED' AND OLD.status <> 'READY' THEN
        RAISE EXCEPTION 'Order % must be READY before COLLECTED', NEW.order_id;
    END IF;
    IF NEW.status = 'DELIVERED' AND OLD.status <> 'READY' THEN
        RAISE EXCEPTION 'Order % must be READY before DELIVERED', NEW.order_id;
    END IF;

    FOR i IN 1..array_length(valid_transitions, 1) LOOP
        IF valid_transitions[i][1] = OLD.status
           AND valid_transitions[i][2] = NEW.status THEN
            allowed := TRUE; EXIT;
        END IF;
    END LOOP;

    IF NOT allowed THEN
        RAISE EXCEPTION 'Invalid status transition % -> % on order %',
            OLD.status, NEW.status, NEW.order_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_status_fsm ON cake_order;
CREATE TRIGGER trg_status_fsm
    BEFORE UPDATE OF status ON cake_order
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status)
    EXECUTE FUNCTION fn_status_fsm();

-- ===== Sanity checks already enforced by CHECK constraints in schema.sql:
--      C3 due_date >= order_date + 2 days
--      C5 tiers 1..5, prices > 0, payments > 0, max_units > 0
--      C2 decorator overlap (EXCLUDE USING btree_gist)
-- =====
