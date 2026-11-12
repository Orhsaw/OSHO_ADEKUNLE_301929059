# Screenshots / evidence to capture

Capture these from the student's OWN Codespace run (or from `my_results.txt`).
Nothing here may be simulated.

| # | Portfolio | What to capture | Source |
| --- | --- | --- | --- |
| 1 | P1 | "Inserted N cake orders" and the stats table | `p1_output.log` |
| 2 | P1 | `over-capacity days (must be 0)` = 0 | `p1_output.log` |
| 3 | P1 | The eight `TEST n PASS` lines | `p1_output.log` |
| 4 | P1 | ER diagram rendered on GitHub | `er_diagram.md` on GitHub |
| 5 | P2 | Before and after `Execution Time` for Q1 to Q6 | `explain_before.log`, `explain_after.log` |
| 6 | P2 | A plan that switched from Seq Scan to Index Only Scan | `explain_after.log` |
| 7 | P3 | `place_order()` success and refusal | `p3_output.log` |
| 8 | P3 | Race bug 42/40, both fixes 40/40, SQLSTATE 40001, SQLSTATE 40P01 | `race_demos_output.log` |
| 9 | P4 | 40,000 documents, aggregation results, COLLSCAN to IXSCAN table | `seed_designs.log`, `aggregations.log`, `index_demo.log` |
| 10 | P5 | Partition list, row counts, pruning plan | `partitioning.log` |
| 11 | P5 | `pg_stat_replication` streaming, rejected write, row arriving, lag | `replication_output.log` |
