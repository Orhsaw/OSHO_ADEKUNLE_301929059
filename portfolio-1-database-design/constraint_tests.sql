-- =====================================================================
-- Portfolio 1 — constraint_tests.sql
-- Eight tests. Each one builds its own situation from the real data and
-- tries to break ONE rule. A test PASSES when the database refuses the
-- change with the intended error; it FAILS (loudly) if the change goes
-- through. Every test runs in a sub-block that is always rolled back, so
-- nothing is left behind in the data.
--   sudo runuser -u postgres -- psql -d sweetcrust -f constraint_tests.sql
-- =====================================================================
\set ON_ERROR_STOP off

\echo '--- Test 1: capacity exceeded: a 5-tier order on a day with 1 unit left ---'
DO $$
DECLARE
    oid    INTEGER;
    dec_id INTEGER;
    bid    INTEGER;
    win    TSTZRANGE;
BEGIN
    BEGIN
        UPDATE daily_capacity SET max_units = 1 WHERE branch_id = 1 AND cap_date = CURRENT_DATE + 40;
        INSERT INTO cake_order(branch_id, customer_id, cake_type_id, order_date, due_date, tiers, size_code, unit_price_ngn, status)
        VALUES (1, 1, 1, CURRENT_DATE + 30, CURRENT_DATE + 40, 1, 'S', 18000, 'PENDING');   -- uses the only unit (allowed)
        INSERT INTO cake_order(branch_id, customer_id, cake_type_id, order_date, due_date, tiers, size_code, unit_price_ngn, status)
        VALUES (1, 1, 1, CURRENT_DATE + 30, CURRENT_DATE + 40, 5, 'XL', 100000, 'PENDING'); -- must be refused
        RAISE EXCEPTION 'NOT_REFUSED';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'NOT_REFUSED' THEN
            RAISE NOTICE 'TEST 1 FAIL: the database accepted the bad change';
        ELSIF SQLERRM LIKE '%Capacity exceeded%' THEN
            RAISE NOTICE 'TEST 1 PASS (refused: SQLSTATE %, %)', SQLSTATE, SQLERRM;
        ELSE
            RAISE NOTICE 'TEST 1 FAIL: wrong error: SQLSTATE %, %', SQLSTATE, SQLERRM;
        END IF;
    END;
END $$;

\echo '--- Test 2: decorator double-booked (overlapping window, same decorator) ---'
DO $$
DECLARE
    oid    INTEGER;
    dec_id INTEGER;
    bid    INTEGER;
    win    TSTZRANGE;
BEGIN
    BEGIN
        SELECT decorator_id, branch_id, decorating_window INTO dec_id, bid, win
          FROM decorator_assignment ORDER BY assignment_id LIMIT 1;
        INSERT INTO decorator_assignment(decorator_id, branch_id, order_id, decorating_window, status)
        SELECT dec_id, bid, order_id, win, 'ASSIGNED'
          FROM cake_order WHERE branch_id = bid AND status <> 'CANCELLED' ORDER BY order_id DESC LIMIT 1;
        RAISE EXCEPTION 'NOT_REFUSED';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'NOT_REFUSED' THEN
            RAISE NOTICE 'TEST 2 FAIL: the database accepted the bad change';
        ELSIF SQLSTATE = '23P01' THEN
            RAISE NOTICE 'TEST 2 PASS (refused: SQLSTATE %, %)', SQLSTATE, SQLERRM;
        ELSE
            RAISE NOTICE 'TEST 2 FAIL: wrong error: SQLSTATE %, %', SQLSTATE, SQLERRM;
        END IF;
    END;
END $$;

\echo '--- Test 3: due_date only 1 day after order_date ---'
DO $$
DECLARE
    oid    INTEGER;
    dec_id INTEGER;
    bid    INTEGER;
    win    TSTZRANGE;
BEGIN
    BEGIN
        INSERT INTO cake_order(branch_id, customer_id, cake_type_id, order_date, due_date, tiers, size_code, unit_price_ngn, status)
        VALUES (1, 1, 1, CURRENT_DATE + 30, CURRENT_DATE + 31, 1, 'S', 18000, 'PENDING');
        RAISE EXCEPTION 'NOT_REFUSED';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'NOT_REFUSED' THEN
            RAISE NOTICE 'TEST 3 FAIL: the database accepted the bad change';
        ELSIF SQLSTATE = '23514' THEN
            RAISE NOTICE 'TEST 3 PASS (refused: SQLSTATE %, %)', SQLSTATE, SQLERRM;
        ELSE
            RAISE NOTICE 'TEST 3 FAIL: wrong error: SQLSTATE %, %', SQLSTATE, SQLERRM;
        END IF;
    END;
END $$;

\echo '--- Test 4: confirm an order with a deposit under 50% ---'
DO $$
DECLARE
    oid    INTEGER;
    dec_id INTEGER;
    bid    INTEGER;
    win    TSTZRANGE;
BEGIN
    BEGIN
        INSERT INTO cake_order(branch_id, customer_id, cake_type_id, order_date, due_date, tiers, size_code, unit_price_ngn, status)
        VALUES (1, 1, 1, CURRENT_DATE + 30, CURRENT_DATE + 41, 1, 'S', 18000, 'PENDING') RETURNING order_id INTO oid;
        INSERT INTO payment(order_id, amount_ngn, kind, method) VALUES (oid, 1000.00, 'deposit', 'cash');
        UPDATE cake_order SET status = 'CONFIRMED' WHERE order_id = oid;
        RAISE EXCEPTION 'NOT_REFUSED';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'NOT_REFUSED' THEN
            RAISE NOTICE 'TEST 4 FAIL: the database accepted the bad change';
        ELSIF SQLERRM LIKE '%Cannot confirm order%' THEN
            RAISE NOTICE 'TEST 4 PASS (refused: SQLSTATE %, %)', SQLSTATE, SQLERRM;
        ELSE
            RAISE NOTICE 'TEST 4 FAIL: wrong error: SQLSTATE %, %', SQLSTATE, SQLERRM;
        END IF;
    END;
END $$;

\echo '--- Test 5: illegal status jump READY -> BAKING ---'
DO $$
DECLARE
    oid    INTEGER;
    dec_id INTEGER;
    bid    INTEGER;
    win    TSTZRANGE;
BEGIN
    BEGIN
        INSERT INTO cake_order(branch_id, customer_id, cake_type_id, order_date, due_date, tiers, size_code, unit_price_ngn, status)
        VALUES (1, 1, 1, CURRENT_DATE + 30, CURRENT_DATE + 42, 1, 'S', 18000, 'PENDING') RETURNING order_id INTO oid;
        INSERT INTO payment(order_id, amount_ngn, kind, method) VALUES (oid, 10000.00, 'deposit', 'cash');
        UPDATE cake_order SET status = 'CONFIRMED'  WHERE order_id = oid;
        UPDATE cake_order SET status = 'BAKING'     WHERE order_id = oid;
        UPDATE cake_order SET status = 'DECORATING' WHERE order_id = oid;
        UPDATE cake_order SET status = 'READY'      WHERE order_id = oid;
        UPDATE cake_order SET status = 'BAKING'     WHERE order_id = oid;   -- illegal
        RAISE EXCEPTION 'NOT_REFUSED';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'NOT_REFUSED' THEN
            RAISE NOTICE 'TEST 5 FAIL: the database accepted the bad change';
        ELSIF SQLERRM LIKE '%Invalid status transition%' THEN
            RAISE NOTICE 'TEST 5 PASS (refused: SQLSTATE %, %)', SQLSTATE, SQLERRM;
        ELSE
            RAISE NOTICE 'TEST 5 FAIL: wrong error: SQLSTATE %, %', SQLSTATE, SQLERRM;
        END IF;
    END;
END $$;

\echo '--- Test 6: revive a CANCELLED order ---'
DO $$
DECLARE
    oid    INTEGER;
    dec_id INTEGER;
    bid    INTEGER;
    win    TSTZRANGE;
BEGIN
    BEGIN
        INSERT INTO cake_order(branch_id, customer_id, cake_type_id, order_date, due_date, tiers, size_code, unit_price_ngn, status)
        VALUES (1, 1, 1, CURRENT_DATE + 30, CURRENT_DATE + 43, 1, 'S', 18000, 'PENDING') RETURNING order_id INTO oid;
        INSERT INTO payment(order_id, amount_ngn, kind, method) VALUES (oid, 10000.00, 'deposit', 'cash');
        UPDATE cake_order SET status = 'CANCELLED' WHERE order_id = oid;
        UPDATE cake_order SET status = 'CONFIRMED' WHERE order_id = oid;
        RAISE EXCEPTION 'NOT_REFUSED';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'NOT_REFUSED' THEN
            RAISE NOTICE 'TEST 6 FAIL: the database accepted the bad change';
        ELSIF SQLERRM LIKE '%cannot be revived%' THEN
            RAISE NOTICE 'TEST 6 PASS (refused: SQLSTATE %, %)', SQLSTATE, SQLERRM;
        ELSE
            RAISE NOTICE 'TEST 6 FAIL: wrong error: SQLSTATE %, %', SQLSTATE, SQLERRM;
        END IF;
    END;
END $$;

\echo '--- Test 7: tiers out of range (0) ---'
DO $$
DECLARE
    oid    INTEGER;
    dec_id INTEGER;
    bid    INTEGER;
    win    TSTZRANGE;
BEGIN
    BEGIN
        INSERT INTO cake_order(branch_id, customer_id, cake_type_id, order_date, due_date, tiers, size_code, unit_price_ngn, status)
        VALUES (1, 1, 1, CURRENT_DATE + 30, CURRENT_DATE + 44, 0, 'S', 18000, 'PENDING');
        RAISE EXCEPTION 'NOT_REFUSED';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'NOT_REFUSED' THEN
            RAISE NOTICE 'TEST 7 FAIL: the database accepted the bad change';
        ELSIF SQLSTATE = '23514' THEN
            RAISE NOTICE 'TEST 7 PASS (refused: SQLSTATE %, %)', SQLSTATE, SQLERRM;
        ELSE
            RAISE NOTICE 'TEST 7 FAIL: wrong error: SQLSTATE %, %', SQLSTATE, SQLERRM;
        END IF;
    END;
END $$;

\echo '--- Test 8: negative price ---'
DO $$
DECLARE
    oid    INTEGER;
    dec_id INTEGER;
    bid    INTEGER;
    win    TSTZRANGE;
BEGIN
    BEGIN
        INSERT INTO cake_order(branch_id, customer_id, cake_type_id, order_date, due_date, tiers, size_code, unit_price_ngn, status)
        VALUES (1, 1, 1, CURRENT_DATE + 30, CURRENT_DATE + 45, 1, 'S', -100, 'PENDING');
        RAISE EXCEPTION 'NOT_REFUSED';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'NOT_REFUSED' THEN
            RAISE NOTICE 'TEST 8 FAIL: the database accepted the bad change';
        ELSIF SQLSTATE = '23514' THEN
            RAISE NOTICE 'TEST 8 PASS (refused: SQLSTATE %, %)', SQLSTATE, SQLERRM;
        ELSE
            RAISE NOTICE 'TEST 8 FAIL: wrong error: SQLSTATE %, %', SQLSTATE, SQLERRM;
        END IF;
    END;
END $$;

\echo '--- Constraint tests finished: look for 8 lines starting TEST n PASS ---'
-- =====================================================================
