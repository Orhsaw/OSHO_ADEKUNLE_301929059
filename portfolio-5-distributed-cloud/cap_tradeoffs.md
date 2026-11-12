# Portfolio 5 — CAP and Sync vs Async Trade-offs

> Companion to `cloud_architecture.md`. This file expands the CAP
> analysis into a side-by-side decision log for SweetCrust Bakery.

## CAP theorem — what SweetCrust chooses

In a distributed system, under a network partition you must pick
**either** Consistency **or** Availability. SweetCrust explicitly chooses:

> **CP** — strong write consistency is non-negotiable because cake orders
> are financial transactions. A double-booked bakery slot is a customer
> compensation event; a briefly-unavailable write endpoint is not.

| | C | A | P |
| --- | --- | --- | --- |
| Meaning | All reads see the latest write or an error | Every request gets a (non-error) response | The system keeps working despite dropped/delayed messages between nodes |
| SweetCrust choice | **Strong** on the primary (linearisable); **eventual** on async replicas | Reads always available from ≥1 replica; writes available only at the Lagos DC | **Yes**, partition-tolerant by design |

### Why CP, not AP

- An AP system would let the Ibadan replica accept writes during a
  Lagos↔Ibadan partition, then try to merge on reconnect — merging two
  conflicting `cake_order` inserts on the same (branch, due_date) slot
  is exactly the overbooking bug from Portfolio 3.
- A CP system blocks the Ibadan replica's writes (`cannot execute INSERT
  in a read-only transaction`) until the partition heals — the bakery
  loses a few orders if the partition is long, but never overbooks.
- The capacity trigger (Portfolio 1) and the `place_order()` procedure
  (Portfolio 3) only ever run on the primary, so CP is naturally enforced.

### Where SweetCrust bends toward AP (read-only)

- The online order tracker reads from the nearest replica. During a
  partition it serves stale-but-valid reads (last-known order status),
  clearly labelled with a `last_synced_at` timestamp on the UI. This is
  AP-for-reads, CP-for-writes.

## Sync vs async replication — decision matrix

| Dimension | Sync replication | Async replication |
| --- | --- | --- |
| Definition | Primary waits for ≥1 standby to flush WAL before COMMIT returns | Primary commits as soon as its own WAL is flushed |
| Write latency | Higher (network round-trip to standby) | Lower (local only) |
| RPO (data loss on primary crash) | 0 (every committed txn is on ≥2 nodes) | > 0 (last few WAL records may be lost; typically < 1 s) |
| RTO (time to failover) | Fast — standby is already caught up, just promote it | Slower — need to wait for catch-up or accept some data loss |
| Behaviour under partition | Standby partition → primary blocks commits (unavailability) | Standby partition → primary keeps accepting commits, replica goes stale |
| SweetCrust fit | Excellent for in-DC DR standby (Lagos primary ↔ Lagos DR replica) — low latency, no acceptable data loss | Excellent for cross-city read replica (Lagos ↔ Ibadan) — partition-tolerant, latency too high for sync |

### SweetCrust's hybrid: near-sync + far-async

```
Lagos DC (primary) ──sync──► Lagos DR standby       (RPO = 0 within DC)
                 └─async──► Ibadan replica           (RPO < 1 s, partition-tolerant)
```

This is the textbook **"sync-near, async-far"** pattern:

1. Within the Lagos DC, sync replication gives RPO = 0 for the worst-case
   single-node failure (the most common failure mode).
2. Lagos → Ibadan uses async because the Lagos↔Ibadan WAN latency would
   make sync replication unacceptable for an OLTP write workload.
3. If Lagos DC fails entirely (rare), we promote the Ibadan async replica
   and accept the last < 1 s of WAL as lost. This is documented as the
   DR RPO.

## Consistency models in use

| Model | Where used | Why |
| --- | --- | --- |
| Linearisable | Primary writes | `place_order()` and the capacity trigger must see all prior writes |
| Read-committed | Online tracker reads from replica | Eventually consistent; user sees `last_synced_at` |
| Causal | Decorator assignment exclusion (EXCLUDE constraint) | Decorator schedules never overlap regardless of which replica served the read |
| Eventual | MongoDB design specs | A design spec being 1 s stale on a read replica is acceptable |

## Partition scenarios

| Scenario | Effect on writes | Effect on reads | User impact |
| --- | --- | --- | --- |
| Single standby crashes | Sync standby gone — primary blocks new commits for ≤ `synchronous_standby_names` timeout | Reads from other replicas continue | 30-second write stall, then auto-fallback |
| Lagos↔Ibadan partition | Primary keeps writing; Ibadan replica goes stale but readable | Tracker serves last-known status with a `stale=true` flag | Bodija staff see slightly old order statuses; Lagos unaffected |
| Lagos DC fails entirely | Promote Lagos DR standby (sync, RPO 0); if also down, promote Ibadan replica (async, RPO < 1 s) | All tracker traffic routes to whichever replica is promoted | Brief outage during promotion; no overbooking possible |
| Network slow but up | Sync standby reply slower → higher write latency | Reads unchanged | Slightly slower checkout |
| Split-brain (rare, only with misconfigured failover) | Risk of two primaries writing conflicting orders | Mitigated by fencing + the capacity trigger refusing any overbook attempt | Manual reconciliation post-incident |

## What this file demonstrates

A documented, NDPA-2023-compliant distributed architecture for
SweetCrust Bakery that:

- keeps all PII in Nigeria,
- chooses CP over AP for the financial core (orders),
- uses **near-sync within Lagos DC + far-async to Ibadan** as a hybrid,
- explicitly documents the RPO/RTO and partition behaviour for each
  failure mode,
- and ties back to Portfolios 1 (capacity trigger) and 3
  (`place_order()` transaction) for the consistency guarantees.
