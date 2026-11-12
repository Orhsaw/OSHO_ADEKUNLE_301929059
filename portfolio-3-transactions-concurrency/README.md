# Portfolio 3 — Transactions & Concurrency

**Demonstrates:** a `place_order()` procedure that runs as one transaction, COMMIT/ROLLBACK/SAVEPOINT, a two-terminal race condition with two fixes (`SELECT ... FOR UPDATE` and `SERIALIZABLE` with retry), the four isolation levels, and an A/B-B/A deadlock demo.

**Course-note study sessions:** 10 (transaction management & ACID) · 11 (concurrency control & isolation levels) · 12 (locking, deadlocks & MVCC) · 13 (recovery & log-based recovery).

## Files

| File | Purpose |
| --- | --- |
| `place_order.sql` | `place_order(...)` procedure: capacity check → insert order → insert deposit → optional confirm, all inside one tx, with explicit COMMIT/ROLLBACK semantics. Includes a success demo and a failure demo. |
| `commit_rollback.sql` | Three psql-level demos: COMMIT path, ROLLBACK path (failed deposit cancels the order), SAVEPOINT path (order survives a failed deposit). |
| `run_race_demos.py` | Opens two real sessions and runs all six concurrency demos in one go; output saved to `race_demos_output.log`. |
| `race_condition_guide.md` | Table explaining each of the six parts and what to look for in the log (bug 42/40, `FOR UPDATE` fix, `SERIALIZABLE` + retry, non-repeatable read, frozen snapshot, deadlock). |
| `isolation_levels.sql` | Single-session reference listing the four isolation levels PostgreSQL accepts; the live behaviour is in `run_race_demos.py`. |
| `deadlock_demo.sql` | Explains the A/B-B/A deadlock; the real one runs in `run_race_demos.py` Part 6 (SQLSTATE 40P01). |

## Run in Codespaces

```bash
bash run_p3.sh          # everything is automated, no second terminal needed
```

## What to screenshot for evidence

1. `place_order()` success notice (`order_id=… price=… deposit=…`).
2. `place_order()` failure (`deposit_pct < 0.50` raises).
3. COMMIT vs ROLLBACK row counts (1 row vs 0 rows).
4. SAVEPOINT row counts (order + deposit both visible after retry).
5. `race_demos_output.log`:
   - Part 1 bug: `RESULT: 42/40 units used  <-- OVERBOOKED`.
   - Part 2 fix: B waits for the lock, then `RESULT: 40/40`.
   - Part 3 fix: `SQLSTATE 40001` for B, retry refused, `RESULT: 40/40`.
   - Parts 4 and 5: non-repeatable read, then the frozen snapshot.
6. Part 6: `DEADLOCK VICTIM  SQLSTATE 40P01`.

## Git commit

```bash
git add portfolio-3-transactions-concurrency/
git commit -m "P3: place_order() tx, COMMIT/ROLLBACK, 2-terminal race + 2 fixes, deadlock"
```

## What this portfolio demonstrates

A complete transactional slice of SweetCrust's order pipeline: an
ACID `place_order()` procedure, COMMIT/ROLLBACK/SAVEPOINT at the psql
level, a reproduced lost-update race (42/40 overbooking) and two standard
fixes (pessimistic `FOR UPDATE` and optimistic `SERIALIZABLE` retry), all
four isolation levels, and a textbook A/B-B/A deadlock with the
`40P01` SQLSTATE.
