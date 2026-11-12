# Portfolio 4 — MongoDB Index: COLLSCAN → IXSCAN

> Replace every `[paste real output here]` with the real numbers from
> running `index_demo.js`. Nothing is simulated.

Run:
```bash
mongosh sweetcrust_designs portfolio-4-nosql/index_demo.js
```

## Before / after summary

| Metric | BEFORE (COLLSCAN) | AFTER (IXSCAN) |
| --- | --- | --- |
| `winningPlan.stage` | `[paste real output here]` | `[paste real output here]` |
| `totalDocsExamined` | `[paste real output here]` | `[paste real output here]` |
| `nReturned` | `[paste real output here]` | `[paste real output here]` |
| `executionTimeMillis` | `[paste real output here]` | `[paste real output here]` |

## Full plans

### Before (COLLSCAN)
```
[paste real output here]
```

### After (IXSCAN)
```
[paste real output here]
```

## Analysis

> Discuss why a COLLSCAN had to examine every one of the 40,000 documents,
> why the compound index `(occasion, theme)` reduced `totalDocsExamined`
> to roughly the number of wedding/White-Rose designs, and the
> execution-time delta. Note that MongoDB automatically uses an index
> when the index covers the equality predicate.

`[paste real output here]`
