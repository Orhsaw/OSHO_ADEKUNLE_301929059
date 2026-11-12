# Portfolio 5 — Streaming replication (what `replication_demo.sh` does)

`replication_demo.sh` builds a **primary** (port 5432) plus a **streaming read replica**
(port 5433) on the one Codespaces machine and demonstrates it end to end. You run it
with `bash run_p5.sh` (it follows `partitioning.sql`); the labelled output is saved to
`replication_output.log`. Nothing is typed by hand.

```
   PRIMARY  (port 5432)  --- WAL stream --->  REPLICA  (port 5433, read-only)
   /var/lib/postgresql/16/main                /var/lib/postgresql/16/replica
   database sweetcrust_p5                     copy of sweetcrust_p5
```

| Step | What the script does | Why |
| --- | --- | --- |
| 0 | Removes any earlier replica, slot and pg_hba lines. | Safe to re-run. |
| 1 | Creates role `repl` (REPLICATION) and inserts its `trust` lines at the **top** of `pg_hba.conf`, then reloads. | Ubuntu's default rules end with a password rule; a trust line appended at the bottom would never be reached. |
| 2 | `pg_basebackup -X stream -R -C -S sweetcrust_slot` from the primary over the Unix socket. | Copies the whole cluster, writes `standby.signal`, and creates a replication slot so no WAL is lost. |
| 3 | Writes a small `postgresql.conf` and copies `pg_hba.conf` / `pg_ident.conf` into the replica directory. | On Ubuntu the config lives in `/etc`, so a base backup has none of these files. |
| 4 | Starts the replica with `pg_ctl` on port 5433. | There is no systemd in Codespaces. |
| 5 | Runs the same query on both ports. | Proves which server is which: `is_replica = f` on 5432 and `t` on 5433. |
| 6 | Reads `pg_stat_replication` on the primary. | `state = streaming`, `sync_state = async`. |
| 7 | **Demo 1**: INSERT on the replica. | `ERROR: cannot execute INSERT in a read-only transaction`. |
| 8 | **Demo 2**: INSERT on the primary, then read it on the replica. | The row arrives through WAL streaming. |
| 9 | Compares `count(*)` of `cake_order` on both and prints the replay lag. | Same data, lag in milliseconds. |
| 10 | Deletes the demo row, stops the replica, drops the slot, restores `pg_hba.conf`. | An unused slot would keep WAL piling up on the primary. |

The replication is **asynchronous**: the primary does not wait for the replica, so a
very recent write can be missing on the replica for a moment (the lag in step 9). See
`cap_tradeoffs.md` for when SweetCrust would choose synchronous replication instead.
