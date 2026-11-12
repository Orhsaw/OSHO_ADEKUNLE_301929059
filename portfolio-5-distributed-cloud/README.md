# Portfolio 5 — Distributed & Cloud Database Exercise

**Demonstrates:** monthly range partitioning of `cake_order`, a primary + streaming read replica (replica rejects writes, new rows arrive via WAL streaming), and a cloud architecture that keeps all data in Nigeria for NDPA 2023 compliance, with CAP and sync-vs-async trade-offs.

**Course-note study sessions:** 18 (distributed DBMS architecture) · 19 (replication: streaming, sync/async) · 20 (partitioning / sharding) · 21 (CAP & consistency models) · 22 (cloud DB deployment, NDPA 2023 & data residency).

## Files

| File | Purpose |
| --- | --- |
| `partitioning.sql` | Recreates `cake_order` as a `PARTITION BY RANGE (due_date)` parent with 29 monthly partitions (history + 3 months ahead) + a default partition; copies the real P1 data (~50k orders) with `\copy ... FROM PROGRAM`; prints partition-pruning EXPLAIN ANALYZE plans + real per-partition row counts. |
| `replication_demo.sh` | ONE script that builds a primary + streaming replica (port 5433) and demonstrates it: who is who, `pg_stat_replication`, a rejected write on the replica, a row arriving from the primary, lag, then cleans up. Output saved to `replication_output.log`. |
| `streaming_replica_setup.md` | Explains what `replication_demo.sh` does, step by step, and why. |
| `cloud_architecture.md` | NDPA-2023-compliant architecture: in-country Lagos primary + Lagos DR + Ibadan replica + MongoDB replica set, with each NDPA principle mapped to its concrete control, CAP/CP-AP analysis, sync-vs-async decision, and December/Valentine's rush handling. |
| `cap_tradeoffs.md` | CAP decision log, sync-vs-async matrix, near-sync + far-async hybrid, RPO/RTO per failure mode. |

## Run in Codespaces

```bash
bash run_p5.sh                    # partitioning.sql, then replication_demo.sh (needs P1 run first)
```

## What to screenshot for evidence

1. `partitioning.log`: the partition list + the real per-partition row counts.
2. The partition-pruning EXPLAIN plan showing **only one** partition scanned.
3. `replication_output.log`: `pg_stat_replication` row with `state = streaming`.
4. The "who is who" table (`is_replica` f on 5432, t on 5433) and the lag line.
5. `ERROR: cannot execute INSERT in a read-only transaction` (Demo 1).
6. The row inserted on the primary appearing on the replica (Demo 2).

## Git commit

```bash
git add portfolio-5-distributed-cloud/
git commit -m "P5: monthly partitioning + streaming replica + NDPA cloud architecture + CAP"
```

## What this portfolio demonstrates

A distributed-database slice of SweetCrust that (a) partitions the
order table by month of `due_date` and demonstrates planner-level
partition pruning, (b) stands up a primary + streaming read replica on
a single Codespaces VM using `pg_basebackup` + a replication slot and
proves both the read-only property of the replica and the eventual
delivery of new rows, and (c) documents an NDPA-2023-compliant cloud
deployment that keeps all PII inside Nigeria, with explicit CAP,
sync-vs-async and rush-handling trade-offs.
