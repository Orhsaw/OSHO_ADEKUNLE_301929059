# Portfolio 5 — Cloud Architecture (NDPA 2023, in-country data residency)

## SweetCrust's distributed database target architecture

SweetCrust Bakery runs four branches across two Nigerian cities:
Lagos (Surulere, Lekki, Ikeja) and Ibadan (Bodija). The online order
tracker must:

- Stay fast for staff in every branch (read-after-write latency < 1 s).
- Keep all customer PII **inside Nigeria** to comply with the **Nigeria
  Data Protection Act, 2023 (NDPA 2023)** and the NDPC's cross-border
  transfer guidance.
- Survive the December, Valentine's and wedding-season demand spikes
  without losing orders.

## High-level architecture

```
                         ┌──────────────────────────────────────┐
                         │      Lagos Region (Primary DC)      │
                         │   e.g. africa-nigeria-lagos-1 (NCC)  │
                         │                                      │
                         │  ┌─────────────┐   async stream    ┌─────────────┐
   branches in ──► ALB──►│  │  PRIMARY    │ ───────────────► │  REPLICA A  │
   Lagos + Ibadan       │  │  sweetcrust │                   │  (read-only)│
                         │  └──────┬──────┘                   └─────────────┘
                         │         │                            │
                         │         │ async stream               │
                         │         ▼                            ▼
                         │  ┌─────────────┐              ┌─────────────┐
                         │  │  REPLICA B  │              │  REPLICA C  │
                         │  │ (Lagos DR)  │              │  (Ibadan)   │
                         │  └─────────────┘              └─────────────┘
                         └──────────────────────────────────────┘
                                          │
                                          │  (data stays in Nigeria;
                                          │   NDPA 2023 compliant)
                                          ▼
                         ┌──────────────────────────────────────┐
                         │     MongoDB replica set              │
                         │     (design specs, in-country)       │
                         │     3 nodes, 1 in Lagos, 1 in Lagos   │
                         │     DR, 1 in Ibadan                   │
                         └──────────────────────────────────────┘
```

**Key choices:**

1. **In-country regions only.** The PostgreSQL primary + replicas and
   the MongoDB replica set all run on a cloud provider's Nigeria region
   (or on a self-managed cluster in a Lagos + Ibadan DC, both physically
   in Nigeria). No data crosses the Nigerian border, satisfying NDPA 2023
   section on cross-border transfer restrictions.

2. **One primary, three replicas.**
   - Primary in Lagos DC (where most orders originate).
   - Replica A in the same Lagos DC for read scaling.
   - Replica B in Lagos DR for HA failover.
   - Replica C in Ibadan to give Bodija staff sub-100 ms reads.

3. **Async streaming replication** between Lagos primary and Ibadan
   replica — fast and resilient to a brief network partition. We accept
   async (not sync) because (a) the order tracker is read-mostly, and
   (b) we cannot tolerate a Lagos↔Ibadan partition blocking writes.

4. **MongoDB replica set** with the same Lagos-primary / Ibadan-replica
   topology. Design-spec reads from Bodija hit the Ibadan mongo node.

5. **Online order tracker** is a read-heavy web app that reads from the
   geographically nearest replica (Lagos branch → Lagos replica, Ibadan
   branch → Ibadan replica). All writes go to the primary.

## NDPA 2023 — Data residency

| NDPA 2023 principle | How this architecture satisfies it |
| --- | --- |
| **Lawful transfer (s. 41 NDPA 2023):** cross-border transfer of personal data requires an adequacy decision or appropriate safeguards. | SweetCrust keeps all PII (customer names, phone numbers, addresses, payment records) on hosts physically located in Nigeria. No PII is replicated to a foreign region; the only cross-border traffic is application logs (anonymised). |
| **Data minimisation:** only collect what's needed. | The order tracker reads only `order_id`, `status`, `due_date`, `branch_id` from the replica — never payment card numbers (which are tokenised at the gateway). |
| **Storage limitation.** | Orders > 7 years old are moved to a cold archive table partitioned by year and only kept in-country for the statutory retention period. |
| **Breach notification (72 hours).** | Replication lag is monitored; a partition > 60 s pages the on-call SRE. The order tracker degrades to read-only mode rather than serving stale writes. |
| **Data Subject Rights (access, rectification, erasure).** | Erasure (`DELETE`) is run on the primary; the replica picks it up via WAL streaming. The MongoDB `designs` collection has a parallel `customer_id` index so the same erasure can run on the design docs. |

## CAP theorem analysis

In distributed-database terms, the architecture is **CP under partition**
with **eventual consistency** for reads served from replicas:

- **Consistency:** writes are linearisable on the primary (single
  source of truth). Replicas are eventually consistent via streaming
  WAL.
- **Availability:** if the Lagos primary fails, the Lagos DR replica is
  promoted (sync or async failover); the cluster keeps serving reads
  from the surviving replicas throughout.
- **Partition tolerance:** Lagos↔Ibadan partition is tolerated; the
  Ibadan replica keeps serving stale-but-valid reads. Writes are never
  accepted on a stale replica.

| CAP flavour | SweetCrust choice | Justification |
| --- | --- | --- |
| **C** (strong) | Linearisable writes on primary; reads can be `READ COMMITTED` from replica with explicit "last-updated" timestamps shown to the user. | Orders are financial transactions — must never double-book a slot. |
| **A** (availability) | Read availability across 3 replicas + failover primary; write availability only at the Lagos DC. | Branches must always be able to read order status; a 30-minute write outage at Lagos is tolerable during DR failover. |
| **P** (partition tolerance) | Async streaming; no sync standby required. | Lagos↔Ibadan partition is plausible; async means the Ibadan replica stays up read-only. |

## Sync vs async replication trade-offs

| Aspect | Synchronous replication | Asynchronous replication (chosen) |
| --- | --- | --- |
| **Write latency** | Higher (waits for at least one standby to flush WAL) | Lower (commit as soon as primary flushes) |
| **Data loss on primary failure** | None (every commit is on ≥2 nodes) | Possible: any WAL not yet streamed is lost (typically < 1 s of data) |
| **Availability under partition** | A partitioned standby blocks commits → unavailability | Commits continue on the primary; the replica is stale but readable |
| **SweetCrust fit** | Too strict for Lagos↔Ibadan latency (single-region within Lagos DC could use sync for DR) | Better fit for the cross-city read replica; the small RPO risk is acceptable for bakery orders |

> SweetCrust uses **sync replication only between the Lagos primary and
> the Lagos DR standby** (low-latency, in-DC), and **async replication
> from Lagos to the Ibadan replica** (high-latency, cross-city). This is
> a common "near-sync + far-async" hybrid.

## Handling the December + Valentine's rush

The demand multiplier from Portfolio 1 spikes:

- December: ~2.0× normal volume (Christmas, end-of-year parties)
- 12–16 Feb: ~2.5× (Valentine's)
- Nov / Dec / Apr: ~1.6× (wedding season)

Mitigations:

1. **Read scaling** — extra replicas spun up in the Lagos DC just for the
   rush window; the online tracker's connection pool routes reads
   round-robin across them. (Read replicas also remove analytical load
   from the primary.)
2. **Partition pruning** — `cake_order` is RANGE-partitioned by month
   (`partitioning.sql`), so the rush queries on December touch only the
   December partition, not 24 months of data.
3. **Capacity headroom** — the `daily_capacity.max_units` cap per branch
   is reviewed quarterly; the Lekki branch is provisioned at 40 units/day
   year-round and bumped to 60 units/day in December via a scheduled
   `UPDATE daily_capacity SET max_units = 60 WHERE cap_date BETWEEN …`
   job (still enforced by the `trg_check_capacity` trigger, so overbooking
   is impossible).
4. **Order tracker backpressure** — if the primary write queue backs up
   (> 200 ms p99), the tracker switches to "queue-and-confirm" mode:
   it ACKs the customer's order with a PENDING status and lets the
   `place_order()` procedure retry once the queue drains. The trigger
   guarantees no slot is ever double-booked.
5. **Connection pool sizing** — PgBouncer in transaction-pooling mode in
   front of the primary, with a hard cap matched to
   `max_connections`. Replica pools are sized independently.
6. **MongoDB** — the `designs` collection is sharded by `occasion` for
   the rush window so wedding-design reads (the heaviest in December)
   hit a dedicated shard.

## Cloud deployment sketch (NDPA-compliant)

| Layer | Service | Region | Notes |
| --- | --- | --- | --- |
| Edge | Cloudflare / local CDN with Nigeria PoP | Global edge, no PII at edge | Static assets only; orders never traverse the edge unencrypted. |
| App tier | 3-node Kubernetes cluster | Nigeria (Lagos) | Read-only pods can be in Ibadan too. |
| PostgreSQL primary | Self-managed or managed Postgres 16 | Nigeria (Lagos) | Async streaming to Ibadan. |
| PostgreSQL replica | Same version | Nigeria (Lagos DR + Ibadan) | Read-only, used by tracker. |
| MongoDB | Replica set 3 nodes | Nigeria (Lagos × 2 + Ibadan × 1) | Design specs. |
| Backups | `pg_basebackup` + WAL archive | Nigeria (Lagos DR) | Encrypted at rest, NDPA retention window. |
| Monitoring | Prometheus + Grafana | Nigeria (Lagos) | Alerts on replication lag, capacity trigger errors, replica write attempts. |

## What to screenshot for evidence

1. The `pg_stat_replication` row showing streaming (from
   `streaming_replica_setup.md` step 7).
2. The replica rejecting the INSERT (Demo 1).
3. The new row visible on the replica after a primary INSERT (Demo 2).
4. The partition-pruning EXPLAIN plan from `partitioning.sql` showing
   only ONE partition scanned.

## Git commit

```bash
git add portfolio-5-distributed-cloud/
git commit -m "P5: monthly partitioning + streaming replica + NDPA cloud architecture + CAP analysis"
```
