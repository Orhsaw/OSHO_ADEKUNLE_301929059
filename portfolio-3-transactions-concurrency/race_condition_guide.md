# Portfolio 3 — Race condition, fixes, isolation levels and deadlock

Everything here is produced by one script, `run_race_demos.py`, which opens two
real PostgreSQL sessions (A and B) and saves the labelled output to
`race_demos_output.log`. Nothing is typed in by hand.

Case: SweetCrust Lekki (branch 2) can bake **40 units** on a day. The day starts
at **38/40** (19 two-tier orders), so exactly one more 2-tier cake fits.

| Part | What it shows | What to look for in `race_demos_output.log` |
| --- | --- | --- |
| 1 | **The bug** (READ COMMITTED). A and B both read 38/40, both insert a 2-tier order before either commits. The capacity trigger cannot see the other session's uncommitted row. | `RESULT: 42/40 units used  <-- OVERBOOKED` |
| 2 | **Fix 1: `SELECT ... FOR UPDATE`** on the `daily_capacity` row. B waits for A's lock, then re-reads 40/40 and refuses. | `B got the lock after waiting ...s`, `RESULT: 40/40` |
| 3 | **Fix 2: `SERIALIZABLE` + retry.** Both insert; A commits; B's commit fails with SQLSTATE `40001`; the retry sees 40/40 and refuses. | `B COMMIT -> FAILED  SQLSTATE 40001`, `RESULT: 40/40` |
| 4 | **READ COMMITTED**: a non-repeatable read (same row read twice in one transaction gives two answers). | `PENDING` then `CONFIRMED` in session A |
| 5 | **REPEATABLE READ**: frozen snapshot; a later UPDATE of the changed row raises SQLSTATE `40001`. | same value twice, then `SQLSTATE 40001` |
| 6 | **Deadlock**: A and B lock two orders in opposite order; PostgreSQL aborts one with SQLSTATE `40P01`. | `DEADLOCK VICTIM  SQLSTATE 40P01` |

Why the trigger alone does not stop Part 1: `trg_check_capacity` sums the rows
**committed** at the moment it runs. If A commits before B inserts, B is refused.
The bug only appears when both sessions insert before either commits, which is
exactly what the script does.

Run it (the runner does this for you):

```bash
sudo runuser -u postgres -- python3 run_race_demos.py | tee race_demos_output.log
```
