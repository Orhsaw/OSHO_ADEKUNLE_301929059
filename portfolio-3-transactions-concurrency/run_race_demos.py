#!/usr/bin/env python3
"""
run_race_demos.py -- Portfolio 3: all concurrency demos in ONE run.

Two real database sessions (A and B) talk to the same PostgreSQL server over the
Unix socket. Every line printed below is real output from this run; nothing is
typed in by hand. Run it as the postgres OS user (peer authentication):

    sudo runuser -u postgres -- python3 run_race_demos.py | tee race_demos_output.log

Case: SweetCrust Lekki (branch 2) can bake 40 units on a given day.
"""
import threading
import time
import psycopg2
from psycopg2 import errors
from psycopg2.extensions import ISOLATION_LEVEL_READ_COMMITTED as RC, \
    ISOLATION_LEVEL_REPEATABLE_READ as RR, ISOLATION_LEVEL_SERIALIZABLE as SER

DSN = "dbname=sweetcrust host=/var/run/postgresql"
BRANCH = 2
DAY_SQL = "CURRENT_DATE + 30"
T0 = time.time()


def log(msg=""):
    print(f"[{time.time() - T0:6.2f}s] {msg}", flush=True)


def conn(iso=RC, name="?"):
    c = psycopg2.connect(DSN)
    c.set_isolation_level(iso)
    return c


def one(c, sql, args=None):
    cur = c.cursor()
    cur.execute(sql, args)
    return cur.fetchone()


def used(c):
    return one(c, f"SELECT COALESCE(SUM(tiers),0) FROM cake_order "
                  f"WHERE branch_id=%s AND due_date={DAY_SQL} AND status<>'CANCELLED'", (BRANCH,))[0]


INSERT_2TIER = (f"INSERT INTO cake_order(branch_id,customer_id,cake_type_id,order_date,due_date,tiers,"
                f"size_code,unit_price_ngn,status,fulfillment_mode) "
                f"VALUES (%s,%s,1,CURRENT_DATE,{DAY_SQL},2,'M',20000,'CONFIRMED','pickup')")


def reset_day():
    """Put Lekki at 38/40 on the demo day: 19 two-tier orders."""
    c = conn(name="setup")
    c.autocommit = True
    cur = c.cursor()
    cur.execute(f"INSERT INTO daily_capacity(branch_id,cap_date,max_units) VALUES (%s,{DAY_SQL},40) "
                f"ON CONFLICT (branch_id,cap_date) DO UPDATE SET max_units=40", (BRANCH,))
    cur.execute(f"DELETE FROM cake_order WHERE branch_id=%s AND due_date={DAY_SQL}", (BRANCH,))
    for cust in range(1, 20):
        cur.execute(f"INSERT INTO cake_order(branch_id,customer_id,cake_type_id,order_date,due_date,tiers,"
                    f"size_code,unit_price_ngn,status,fulfillment_mode) "
                    f"VALUES (%s,%s,1,CURRENT_DATE,{DAY_SQL},2,'M',20000,'DELIVERED','pickup')", (BRANCH, cust))
    n = used(c)
    c.close()
    log(f"reset: Lekki on the demo day is now {n}/40 units used")


def header(title):
    print()
    print("=" * 72)
    print(title)
    print("=" * 72, flush=True)


# ----------------------------------------------------------------------
header("PART 1 -- THE BUG: two READ COMMITTED sessions both book the last 2 units")
reset_day()
A, B = conn(RC, "A"), conn(RC, "B")
log(f"session A = backend pid {A.info.backend_pid}, session B = backend pid {B.info.backend_pid}")
log(f"A reads used units: {used(A)}/40  -> 'room for a 2-tier cake'")
log(f"B reads used units: {used(B)}/40  -> 'room for a 2-tier cake'")
A.cursor().execute(INSERT_2TIER, (BRANCH, 20)); log("A inserted a 2-tier order (not committed yet)")
B.cursor().execute(INSERT_2TIER, (BRANCH, 21)); log("B inserted a 2-tier order (capacity trigger cannot see A's uncommitted row)")
A.commit(); log("A COMMIT")
B.commit(); log("B COMMIT")
chk = conn(name="check")
log(f"RESULT: {used(chk)}/40 units used  <-- OVERBOOKED (the bug)")
A.close(); B.close(); chk.close()

# ----------------------------------------------------------------------
header("PART 2 -- FIX 1: SELECT ... FOR UPDATE on the daily_capacity row")
reset_day()
A, B = conn(RC, "A"), conn(RC, "B")
cur = A.cursor()
cur.execute(f"SELECT max_units FROM daily_capacity WHERE branch_id=%s AND cap_date={DAY_SQL} FOR UPDATE", (BRANCH,))
log(f"A took the row lock; A reads {used(A)}/40")
result = {}


def b_work():
    cb = B.cursor()
    t = time.time()
    log("B asks for the same row lock ... (it will have to wait)")
    cb.execute(f"SELECT max_units FROM daily_capacity WHERE branch_id=%s AND cap_date={DAY_SQL} FOR UPDATE", (BRANCH,))
    result["waited"] = time.time() - t
    log(f"B got the lock after waiting {result['waited']:.2f}s; B now reads {used(B)}/40")
    if used(B) + 2 > 40:
        log("B decides: day fully booked -> ROLLBACK (no overbooking)")
        B.rollback()
    else:
        cb.execute(INSERT_2TIER, (BRANCH, 21)); B.commit()


th = threading.Thread(target=b_work); th.start()
time.sleep(1.5)
log("A inserts its 2-tier order and COMMITs (this releases the lock)")
A.cursor().execute(INSERT_2TIER, (BRANCH, 20)); A.commit()
th.join()
chk = conn(name="check")
log(f"RESULT: {used(chk)}/40 units used  <-- never overbooked")
A.close(); B.close(); chk.close()

# ----------------------------------------------------------------------
header("PART 3 -- FIX 2: SERIALIZABLE isolation + retry on SQLSTATE 40001")
reset_day()
A, B = conn(SER, "A"), conn(SER, "B")
log(f"A reads {used(A)}/40, B reads {used(B)}/40 (both SERIALIZABLE)")
A.cursor().execute(INSERT_2TIER, (BRANCH, 20)); log("A inserted a 2-tier order")
B.cursor().execute(INSERT_2TIER, (BRANCH, 21)); log("B inserted a 2-tier order")
A.commit(); log("A COMMIT -> succeeded")
try:
    B.commit()
    log("B COMMIT -> succeeded (unexpected)")
except psycopg2.Error as e:
    log(f"B COMMIT -> FAILED  SQLSTATE {e.pgcode}: {str(e).splitlines()[0]}")
    B.rollback()
    log("B retries in a new SERIALIZABLE transaction")
    n = used(B)
    log(f"B re-reads {n}/40 -> " + ("day fully booked, order refused" if n + 2 > 40 else "room available"))
    B.rollback()
chk = conn(name="check")
log(f"RESULT: {used(chk)}/40 units used  <-- never overbooked")
A.close(); B.close(); chk.close()

# ----------------------------------------------------------------------
header("PART 4 -- READ COMMITTED: non-repeatable read")
reset_day()
setup = conn(name="setup"); setup.autocommit = True
oid = one(setup, f"INSERT INTO cake_order(branch_id,customer_id,cake_type_id,order_date,due_date,tiers,size_code,"
                 f"unit_price_ngn,status) VALUES (3,1,1,CURRENT_DATE,CURRENT_DATE+33,1,'S',18000,'PENDING') "
                 f"RETURNING order_id")[0]
one(setup, "INSERT INTO payment(order_id,amount_ngn,kind,method) VALUES (%s,9000,'deposit','card') RETURNING 1", (oid,))
A, B = conn(RC, "A"), conn(RC, "B")
log(f"demo order {oid} is PENDING")
log(f"A (READ COMMITTED) first read:  {one(A, 'SELECT status FROM cake_order WHERE order_id=%s', (oid,))[0]}")
B.cursor().execute("UPDATE cake_order SET status='CONFIRMED' WHERE order_id=%s", (oid,)); B.commit()
log("B updated the order to CONFIRMED and COMMITTED")
log(f"A (READ COMMITTED) second read: {one(A, 'SELECT status FROM cake_order WHERE order_id=%s', (oid,))[0]}  <-- changed inside one transaction")
A.rollback()

# ----------------------------------------------------------------------
header("PART 5 -- REPEATABLE READ: frozen snapshot, then SQLSTATE 40001 on update")
oid2 = one(setup, f"INSERT INTO cake_order(branch_id,customer_id,cake_type_id,order_date,due_date,tiers,size_code,"
                  f"unit_price_ngn,status) VALUES (3,1,1,CURRENT_DATE,CURRENT_DATE+34,1,'S',18000,'PENDING') "
                  f"RETURNING order_id")[0]
one(setup, "INSERT INTO payment(order_id,amount_ngn,kind,method) VALUES (%s,9000,'deposit','card') RETURNING 1", (oid2,))
A, B = conn(RR, "A"), conn(RC, "B")
log(f"demo order {oid2} is PENDING")
log(f"A (REPEATABLE READ) first read:  {one(A, 'SELECT status FROM cake_order WHERE order_id=%s', (oid2,))[0]}")
B.cursor().execute("UPDATE cake_order SET status='CONFIRMED' WHERE order_id=%s", (oid2,)); B.commit()
log("B updated the order to CONFIRMED and COMMITTED")
log(f"A (REPEATABLE READ) second read: {one(A, 'SELECT status FROM cake_order WHERE order_id=%s', (oid2,))[0]}  <-- same as first read (snapshot frozen)")
try:
    A.cursor().execute("UPDATE cake_order SET status='CANCELLED' WHERE order_id=%s", (oid2,))
    log("A update succeeded (unexpected)")
except psycopg2.Error as e:
    log(f"A tries to UPDATE the same row -> SQLSTATE {e.pgcode}: {str(e).splitlines()[0]}")
A.rollback(); B.close(); A.close()

# ----------------------------------------------------------------------
header("PART 6 -- DEADLOCK: two sessions lock two orders in opposite order")
o1 = one(setup, f"INSERT INTO cake_order(branch_id,customer_id,cake_type_id,order_date,due_date,tiers,size_code,"
                f"unit_price_ngn,status) VALUES (3,1,1,CURRENT_DATE,CURRENT_DATE+35,1,'S',18000,'PENDING') "
                f"RETURNING order_id")[0]
o2 = one(setup, f"INSERT INTO cake_order(branch_id,customer_id,cake_type_id,order_date,due_date,tiers,size_code,"
                f"unit_price_ngn,status) VALUES (3,1,1,CURRENT_DATE,CURRENT_DATE+36,1,'S',18000,'PENDING') "
                f"RETURNING order_id")[0]
A, B = conn(RC, "A"), conn(RC, "B")
log(f"orders {o1} and {o2} created; A = pid {A.info.backend_pid}, B = pid {B.info.backend_pid}")
A.cursor().execute("UPDATE cake_order SET fulfillment_mode='delivery' WHERE order_id=%s", (o1,)); log(f"A locked order {o1}")
B.cursor().execute("UPDATE cake_order SET fulfillment_mode='delivery' WHERE order_id=%s", (o2,)); log(f"B locked order {o2}")
outcome = {}


def go(c, oid, key):
    try:
        c.cursor().execute("UPDATE cake_order SET fulfillment_mode='pickup' WHERE order_id=%s", (oid,))
        c.commit()
        outcome[key] = "committed"
    except psycopg2.Error as e:
        outcome[key] = f"DEADLOCK VICTIM  SQLSTATE {e.pgcode}: {str(e).splitlines()[0]}"
        c.rollback()


ta = threading.Thread(target=go, args=(A, o2, "A")); ta.start(); log(f"A now wants order {o2} (held by B) ... waits")
time.sleep(0.5)
tb = threading.Thread(target=go, args=(B, o1, "B")); tb.start(); log(f"B now wants order {o1} (held by A) ... circular wait")
ta.join(); tb.join()
log(f"A: {outcome['A']}")
log(f"B: {outcome['B']}")
log("PostgreSQL's deadlock detector aborted one session; the other one finished.")

# ----------------------------------------------------------------------
header("CLEAN-UP")
cur = setup.cursor()
cur.execute(f"DELETE FROM cake_order WHERE (branch_id=%s AND due_date={DAY_SQL}) OR order_id IN (%s,%s,%s,%s)",
            (BRANCH, oid, oid2, o1, o2))
log(f"removed the demo orders ({cur.rowcount} rows); the bulk data is untouched")
print("\nrace_demos finished OK")
