# Portfolio 2 — Before / After Indexing Results

> Replace every `[paste real output here]` with the actual EXPLAIN ANALYZE
> output captured from your Codespaces run. Nothing is faked here.

Run order:
1. `bash run_p2.sh` (this runs `explain_before.sql`, then `indexes.sql`,
   then `explain_after.sql` automatically).
2. Copy each block of EXPLAIN ANALYZE output into the matching cell below.
3. Re-run `queries.sql` to get the result rows themselves.

## Execution time summary (fill in from EXPLAIN ANALYZE `Execution Time`)

| Query | Before — Execution Time | After — Execution Time | Speed-up | Notes |
| --- | --- | --- | --- | --- |
| Q1 remaining capacity next 7 days | `[paste real output here]` ms | `[paste real output here]` ms | `[paste real output here]` x | Window on `due_date`; look for Index Only Scan on `idx_order_due_date_cover` in the AFTER plan |
| Q2 orders per cake type per month | `[paste real output here]` ms | `[paste real output here]` ms | `[paste real output here]` x | Window on `order_date`; look for Index Only Scan on `idx_order_order_date_cover` |
| Q3 revenue per branch | `[paste real output here]` ms | `[paste real output here]` ms | `[paste real output here]` x | Orders use `idx_order_due_date_cover`; `payment` is still read with a Seq Scan (explain why in the analysis) |
| Q4 most popular flavours | `[paste real output here]` ms | `[paste real output here]` ms | `[paste real output here]` x | Whole-table aggregate: a Seq Scan is the right plan, no index helps (say so honestly) |
| Q5 average deposit percentage | `[paste real output here]` ms | `[paste real output here]` ms | `[paste real output here]` x | Orders use `idx_order_due_date_cover`; `payment` still a Seq Scan or hash join |
| Q6 cancellation rate per branch | `[paste real output here]` ms | `[paste real output here]` ms | `[paste real output here]` x | Whole-table aggregate: a Seq Scan is the right plan, no index helps (say so honestly) |

## Full EXPLAIN ANALYZE plans

### Q1 — remaining capacity per branch, next 7 days

**Before:**
```
[paste real output here]
```

**After:**
```
[paste real output here]
```

### Q2 — orders per cake type per month

**Before:**
```
[paste real output here]
```

**After:**
```
[paste real output here]
```

### Q3 — revenue per branch

**Before:**
```
[paste real output here]
```

**After:**
```
[paste real output here]
```

### Q4 — most popular flavours

**Before:**
```
[paste real output here]
```

**After:**
```
[paste real output here]
```

### Q5 — average deposit percentage

**Before:**
```
[paste real output here]
```

**After:**
```
[paste real output here]
```

### Q6 — cancellation rate per branch

**Before:**
```
[paste real output here]
```

**After:**
```
[paste real output here]
```

## Analysis (write 4–6 sentences after collecting real numbers)

> Discuss which plans changed from sequential scans to index scans, the
> effect of the partial indexes (`WHERE status = 'CANCELLED'` and
> `WHERE status <> 'CANCELLED'`), and any query that did not improve
> (e.g. Q4 if `order_flavour` is small enough that a seq scan wins).

`[paste real output here]`
