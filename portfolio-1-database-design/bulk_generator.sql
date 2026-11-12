-- =====================================================================
-- Portfolio 1 — bulk_generator.sql
-- Generates 50,000+ cake orders across 2 years (716 days of history plus the
-- next 14 days of bookings), plus their
-- payments, order_flavour rows and decorator assignments.
--
--   sudo runuser -u postgres -- psql -d sweetcrust -f bulk_generator.sql
--
-- Realistic Nigerian names, prices in NGN (₦), and demand that spikes:
--   - December         (x2.0 orders)        -> Christmas / end-of-year
--   - 12-16 Feb        (x2.5 orders)        -> Valentine's
--   - Nov, Dec, Apr    (x1.6 orders)        -> wedding season
--
-- Each generated day per branch respects the daily_capacity cap so the
-- capacity trigger (C1) never refuses a generated order.
-- =====================================================================

-- ===== Helper: demand multiplier for a given date ===================
-- Higher in December, around Valentine's, and during the wedding season.
CREATE OR REPLACE FUNCTION demand_multiplier(d DATE)
RETURNS REAL LANGUAGE SQL IMMUTABLE AS $$
    SELECT CASE
        WHEN to_char(d,'MM') = '12'                       THEN 2.0  -- Christmas rush
        WHEN to_char(d,'MM-DD') BETWEEN '02-12' AND '02-16' THEN 2.5  -- Valentine's
        WHEN to_char(d,'MM') IN ('11','12','04')         THEN 1.6  -- wedding season
        WHEN to_char(d,'D') IN ('1','7')                  THEN 1.2  -- weekend
        ELSE 1.0
    END;
$$;

-- ===== Helper: pick a random Nigerian-ish name =======================
-- Uses a deterministic set of first/last names so the generator is
-- reproducible with the same seed.
CREATE OR REPLACE FUNCTION random_first_name()
RETURNS TEXT LANGUAGE SQL VOLATILE AS $$
    SELECT n[1 + floor(random()*array_length(n,1))::int]
    FROM (SELECT ARRAY[
        'Adekunle','Chioma','Tunde','Ngozi','Ibrahim','Funke','Emeka','Aisha',
        'Bola','Kunle','Seyi','Adaeze','Chinedu','Halima','Tosin','Zainab',
        'Bisola','Ebuka','Fatima','Dami','Olu','Yetunde','Kemi','Sade','Bayo',
        'Bimbo','Ify','Bukola','Yemi','Nneka','Ganiyu','Amina','Uche','Tomiwa',
        'Kehinde','Taiwo','Jumoke','Rasheed','Folake','Dele','Ore',
        'Onyeka','Adebayo','Olamide','Hauwa','Chika','Tope','Lola','Chidi',
        'Samuel','Daniel','David','Esther','Patience'
    ] AS n) t;
$$;

CREATE OR REPLACE FUNCTION random_last_name()
RETURNS TEXT LANGUAGE SQL VOLATILE AS $$
    SELECT n[1 + floor(random()*array_length(n,1))::int]
    FROM (SELECT ARRAY[
        'Osho','Adeyemi','Bakare','Eze','Sani','Akindele','Obi','Bello',
        'Tinubu','Adeoti','Okafor','Adewale','Dauda','Lawal','Olawale','Yusuf',
        'Mohammed','Ogunleye','Okoro','Balogun','Ibrahim','Nwosu',
        'Oyelaran','Ojo','Fasina','Abdul','Okeke','Olawumi',
        'Animashaun','Adebanjo','Oyelowo','Bankole','Adekoya',
        'Adeyemo','Salami','Akande','Okonkwo','Igwe','Onuoha','Ajaero',
        'Okorie','Ahmed','Mustapha','Idris','Olayinka','Falola',
        'Ogunyemi','Olagunju','Owoeye','Olawoyin','Oyebode','Sodipo'
    ] AS n) t;
$$;

-- ===== Generate customers first (5,000 of them) ======================
TRUNCATE customer RESTART IDENTITY CASCADE;
INSERT INTO customer(first_name, last_name, phone, email, city)
SELECT random_first_name(),
       random_last_name(),
       (ARRAY['0803','0805','0807','0810','0813','0802','0706','0816'])[1 + floor(random()*8)::int]
           || lpad((floor(random()*9999999)::int)::text, 7, '0'),
       NULL,
       (ARRAY['Lagos','Lagos','Lagos','Ibadan'])[1 + floor(random()*4)::int]
FROM generate_series(1, 5000);

-- ===== Generate orders: 716 days of history + the next 14 days =======
-- The generator picks a number of units for each (branch, day) pair that
-- never exceeds the branch's daily_capacity, then writes one cake_order
-- row per order, with tiers weighted toward small cakes.
-- Past due dates -> DELIVERED / COLLECTED / CANCELLED.
-- Future due dates -> PENDING / CONFIRMED / CANCELLED (so P3 and the
-- constraint tests always have real upcoming bookings to work with).
TRUNCATE cake_order RESTART IDENTITY CASCADE;
TRUNCATE order_flavour RESTART IDENTITY CASCADE;
TRUNCATE payment RESTART IDENTITY CASCADE;
TRUNCATE decorator_assignment RESTART IDENTITY CASCADE;

DO $$
DECLARE
    d          DATE;
    b_row      RECORD;
    cap_units  INTEGER;
    target_n   INTEGER;
    used_units INTEGER;
    cust_id    INTEGER;
    type_id    INTEGER;
    tiers      SMALLINT;
    size_code  TEXT;
    base       NUMERIC(12,2);
    price      NUMERIC(12,2);
    ord_date   DATE;
    ord_id     INTEGER;
    ord_status TEXT;
    mode_      TEXT;
    dep_amt    NUMERIC(12,2);
    r          REAL;
    counter    INTEGER := 0;
    n_cust     INTEGER;
BEGIN
    SELECT COUNT(*) INTO n_cust FROM customer;

    FOR d IN SELECT CURRENT_DATE - 716 + g FROM generate_series(0, 729) g LOOP

        FOR b_row IN SELECT branch_id FROM branch LOOP
            SELECT dc.max_units INTO cap_units
              FROM daily_capacity dc
             WHERE dc.branch_id = b_row.branch_id AND dc.cap_date = d;

            -- Units to book that day: ~95% of capacity x demand multiplier,
            -- capped at the branch capacity.
            target_n := LEAST(
                cap_units,
                GREATEST(1, ROUND(cap_units * 0.95 * demand_multiplier(d))::int)
            );
            -- Future days are only partly booked (leave room for P3 demos).
            IF d > CURRENT_DATE THEN
                target_n := GREATEST(1, ROUND(target_n * 0.5)::int);
            END IF;
            used_units := 0;

            WHILE used_units < target_n LOOP
                r := random();
                tiers := CASE
                    WHEN r < 0.60 THEN 1
                    WHEN r < 0.80 THEN 2
                    WHEN r < 0.90 THEN 3
                    WHEN r < 0.96 THEN 4
                    ELSE 5
                END;
                IF used_units + tiers > cap_units THEN
                    tiers := 1;
                    IF used_units + tiers > cap_units THEN EXIT; END IF;
                END IF;

                r := random();
                type_id := CASE
                    WHEN to_char(d,'MM') = '12' AND r < 0.30 THEN 2
                    WHEN to_char(d,'MM-DD') BETWEEN '02-12' AND '02-16' AND r < 0.20 THEN 2
                    WHEN r < 0.55 THEN 1
                    WHEN r < 0.80 THEN 3
                    ELSE 4
                END;

                SELECT base_price_ngn INTO base FROM cake_type WHERE cake_type_id = type_id;
                size_code := (ARRAY['S','M','L','XL'])[1 + floor(random()*4)::int];
                price := base + tiers * 8000.00
                    + CASE size_code WHEN 'S' THEN 0 WHEN 'M' THEN 3000 WHEN 'L' THEN 7000 ELSE 12000 END;

                ord_date := d - (2 + floor(random()*8)::int);
                cust_id  := 1 + floor(random()*n_cust)::int;
                mode_    := CASE WHEN random() < 0.7 THEN 'pickup' ELSE 'delivery' END;

                r := random();
                IF d <= CURRENT_DATE THEN
                    ord_status := CASE WHEN r < 0.04 THEN 'CANCELLED'
                                       WHEN mode_ = 'pickup' THEN 'COLLECTED'
                                       ELSE 'DELIVERED' END;
                ELSE
                    ord_status := CASE WHEN r < 0.04 THEN 'CANCELLED'
                                       WHEN r < 0.15 THEN 'PENDING'
                                       ELSE 'CONFIRMED' END;
                END IF;

                INSERT INTO cake_order (branch_id, customer_id, cake_type_id,
                                        order_date, due_date, tiers, size_code,
                                        unit_price_ngn, status, fulfillment_mode)
                VALUES (b_row.branch_id, cust_id, type_id, ord_date, d, tiers,
                        size_code, price, ord_status, mode_)
                RETURNING order_id INTO ord_id;

                -- One flavour per tier.
                INSERT INTO order_flavour(order_id, flavour_id, tier_no)
                SELECT ord_id, 1 + floor(random()*8)::int, t
                  FROM generate_series(1, tiers) t;

                -- Payments: PENDING orders have paid nothing yet. Everything
                -- else paid a 50% deposit between order date and due date;
                -- finished orders also paid the balance on the due date.
                IF ord_status <> 'PENDING' THEN
                    dep_amt := ROUND(price * 0.5, 2);
                    INSERT INTO payment(order_id, amount_ngn, paid_at, kind, method)
                    VALUES (ord_id, dep_amt,
                            (ord_date::timestamp + random() * interval '36 hours') AT TIME ZONE 'Africa/Lagos',
                            'deposit',
                            (ARRAY['card','transfer','cash','pos'])[1 + floor(random()*4)::int]);
                    IF ord_status IN ('COLLECTED','DELIVERED') THEN
                        INSERT INTO payment(order_id, amount_ngn, paid_at, kind, method)
                        VALUES (ord_id, ROUND(price - dep_amt, 2),
                                (d::timestamp + interval '8 hours' + random() * interval '8 hours') AT TIME ZONE 'Africa/Lagos',
                                'balance',
                                (ARRAY['card','transfer','cash','pos'])[1 + floor(random()*4)::int]);
                    END IF;
                END IF;

                used_units := used_units + tiers;
                counter := counter + 1;
            END LOOP;
        END LOOP;
    END LOOP;

    RAISE NOTICE 'Inserted % cake orders', counter;
END $$;

-- ===== Decorator assignments (set-based, no overlaps) ================
-- Orders due from 30 days ago to 14 days ahead. Each branch has 5
-- decorators; the orders of a (branch, day) are dealt round-robin to the
-- decorators and each decorator gets back-to-back 50-minute windows from
-- 06:00 Lagos time, so the EXCLUDE constraint is never violated and no
-- order is assigned twice.
INSERT INTO decorator_assignment(decorator_id, branch_id, order_id, decorating_window, status)
SELECT 1000 + branch_id * 10 + ((rn - 1) % 5),
       branch_id,
       order_id,
       tstzrange(
           ((due_date::timestamp + interval '6 hours') AT TIME ZONE 'Africa/Lagos') + ((rn - 1) / 5) * interval '1 hour',
           ((due_date::timestamp + interval '6 hours') AT TIME ZONE 'Africa/Lagos') + ((rn - 1) / 5) * interval '1 hour' + interval '50 minutes',
           '[)'),
       CASE WHEN due_date < CURRENT_DATE THEN 'DONE' ELSE 'ASSIGNED' END
  FROM (
    SELECT order_id, branch_id, due_date,
           row_number() OVER (PARTITION BY branch_id, due_date ORDER BY order_id) AS rn
      FROM cake_order
     WHERE status <> 'CANCELLED'
       AND due_date BETWEEN CURRENT_DATE - 30 AND CURRENT_DATE + 14
  ) q;

-- Refresh planner statistics after the bulk load.
ANALYZE;

-- ===== Stats print ==================================================
SELECT 'branches'                              AS what, COUNT(*)::text AS n FROM branch
UNION ALL SELECT 'daily_capacity rows',         COUNT(*)::text FROM daily_capacity
UNION ALL SELECT 'customers',                    COUNT(*)::text FROM customer
UNION ALL SELECT 'cake_types',                   COUNT(*)::text FROM cake_type
UNION ALL SELECT 'flavours',                     COUNT(*)::text FROM flavour
UNION ALL SELECT 'cake_orders',                  COUNT(*)::text FROM cake_order
UNION ALL SELECT 'order_flavour rows',           COUNT(*)::text FROM order_flavour
UNION ALL SELECT 'payments',                     COUNT(*)::text FROM payment
UNION ALL SELECT 'decorator_assignments',        COUNT(*)::text FROM decorator_assignment
UNION ALL SELECT 'earliest due_date',            MIN(due_date)::text FROM cake_order
UNION ALL SELECT 'latest due_date',              MAX(due_date)::text FROM cake_order;

-- Confirm no single (branch, due_date) exceeds capacity:
SELECT 'over-capacity days (must be 0)' AS check_name,
       COUNT(*)::text AS n
  FROM (
    SELECT co.branch_id, co.due_date
      FROM cake_order co
      JOIN daily_capacity dc
        ON dc.branch_id = co.branch_id AND dc.cap_date = co.due_date
     WHERE co.status <> 'CANCELLED'
     GROUP BY co.branch_id, co.due_date, dc.max_units
    HAVING SUM(co.tiers) > dc.max_units
  ) q;
-- =====================================================================
