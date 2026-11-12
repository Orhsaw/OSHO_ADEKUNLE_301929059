# Portfolio 1 — 3NF Normalisation Notes

## 1NF — Atomic values, primary keys

Every table has a single-valued attribute per cell and a primary key:

- `cake_order.tiers` is one integer (1..5), not a comma list.
- The flavours per tier are NOT stored as a CSV in `cake_order`; they live in
  `order_flavour(order_id, flavour_id, tier_no)` so each row is atomic.
- `payment.kind` is a single enum-ish text (`deposit` or `balance`), never a
  list.

## 2NF — No partial dependencies (all-composite PKs)

Only two tables have composite primary keys:

- `daily_capacity (branch_id, cap_date) -> max_units`.
  `max_units` depends on the whole key, not on `branch_id` alone (the
  capacity is per branch **and** per date). 2NF satisfied.
- `order_flavour (order_id, flavour_id, tier_no)`.
  The only non-key column here is implicit (the relationship itself). No
  partial dependency possible. 2NF satisfied.

All other tables have single-column surrogate PKs, so partial dependencies
are impossible by construction.

## 3NF — No transitive dependencies

- `branch.address` and `branch.city` depend only on `branch_id` (the PK),
  not on `name`. 3NF satisfied.
- `cake_type.base_price_ngn` depends on `cake_type_id` only — it is not
  stored on `cake_order` (which would be a transitive dependency). The order
  stores its own `unit_price_ngn` snapshot, which is correct because the
  quoted price must not change if the catalogue price later changes.
- `customer` attributes all depend on `customer_id` only.
- `payment.amount_ngn` and `payment.paid_at` depend on `payment_id` only;
  they are not stored on `cake_order` (which would repeat per payment).
- `decorator_assignment.decorating_window` depends on `assignment_id`
  only; the decorator's own attributes (e.g. a future `decorator.name`)
  would belong in a separate `decorator` table, not repeated here.

## Why this is 3NF (and why BCNF is also satisfied)

Every non-trivial functional dependency `X -> Y` in the schema has `X` as a
superkey, so the schema is actually in **BCNF** (and therefore in 3NF).
The only multi-valued dependency (order → flavours per tier) is resolved
by the `order_flavour` bridge table, so the design is also 4NF-safe.

## Denormalisation deliberately avoided

For an OLTP order-entry workload the schema stays fully normalised:

- No price copied into `cake_order` *except* `unit_price_ngn`, which is a
  justified snapshot (the quoted price the customer agreed to).
- No branch/capacity summary table; `daily_capacity` is the source of truth
  and the trigger `trg_check_capacity` enforces it on every insert.
- Reporting rollups (revenue per branch, cancellations per month, etc.)
  are computed by Portfolio 2 queries, not stored.

## Tables in scope (9)

1. `branch` — PK `branch_id`
2. `daily_capacity` — PK `(branch_id, cap_date)`
3. `customer` — PK `customer_id`
4. `cake_type` — PK `cake_type_id`
5. `flavour` — PK `flavour_id`
6. `cake_order` — PK `order_id`
7. `order_flavour` — PK `(order_id, flavour_id, tier_no)`
8. `payment` — PK `payment_id`
9. `decorator_assignment` — PK `assignment_id` (+ EXCLUDE constraint)
