# Portfolio 2 — Query Processing & Optimisation

**Demonstrates:** 7 analytical queries, EXPLAIN ANALYZE before and after indexing, before/after comparison table with real captured output.

**Course-note study sessions:** 6 (relational algebra & SQL) · 7 (query processing & execution plans) · 8 (indexing — B-tree, partial, composite) · 9 (query optimisation, cost model, statistics, EXPLAIN ANALYZE).

## Files

| File | Purpose |
| --- | --- |
| `queries.sql` | 7 queries: remaining capacity next 7 days, orders/cake type/month, revenue per branch, popular flavours, avg deposit %, cancellation rate, 30-day utilisation trend. |
| `explain_before.sql` | EXPLAIN ANALYZE for the 6 measured queries *before* any analytical index exists. |
| `indexes.sql` | 3 covering indexes (on `due_date`, `order_date`, and payment `(order_id, kind)`) + `VACUUM (ANALYZE)`. |
| `explain_after.sql` | Identical EXPLAIN ANALYZE *after* indexing, for a like-for-like comparison. |
| `before_after_table.md` | Result table + every full plan goes here as `[paste real output here]`. |

## Run in Codespaces

```bash
bash run_p2.sh
```

## What to screenshot for evidence

1. The `Execution Time:` lines from `explain_before.log` and
   `explain_after.log` side by side.
2. At least one plan that visibly switched from `Seq Scan` to
   `Index Scan` / `Index Only Scan`.
3. The result tables for the 7 queries from `queries.log`.

## Git commit

```bash
git add portfolio-2-query-optimisation/
git commit -m "P2: analytical queries + EXPLAIN ANALYZE before/after indexing"
```

## What this portfolio demonstrates

A query-processing portfolio that starts from a baseline plan, adds three
covering indexes, and measures the plan and execution-time change with EXPLAIN
ANALYZE. Q1, Q2, Q3, Q5 and Q7 read a short date window, so an index can help
them. Q4 (flavour popularity) and Q6 (cancellation rate) aggregate the whole
table, so a sequential scan is the right plan and no index will beat it. The
report says so honestly rather than claiming every query improved.
