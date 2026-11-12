# Portfolio 1 — ER Diagram (Mermaid)

**Case study:** SweetCrust Bakery — custom cake orders across 4 branches
(Lagos: Surulere, Lekki, Ikeja; Ibadan: Bodija).

~9 entities: `branch`, `daily_capacity`, `customer`, `cake_type`, `flavour`,
`cake_order`, `order_flavour`, `payment`, `decorator_assignment`.

## ER Diagram (Mermaid)

```mermaid
erDiagram
    BRANCH ||--o{ DAILY_CAPACITY : "sets capacity per date"
    BRANCH ||--o{ CAKE_ORDER : "fulfils orders"
    BRANCH ||--o{ DECORATOR_ASSIGNMENT : "hosts decorating jobs"
    CUSTOMER ||--o{ CAKE_ORDER : "places"
    CAKE_TYPE ||--o{ CAKE_ORDER : "classifies"
    CAKE_ORDER ||--o{ ORDER_FLAVOUR : "has per tier"
    CAKE_ORDER ||--o{ PAYMENT : "is paid by"
    CAKE_ORDER ||--o{ DECORATOR_ASSIGNMENT : "is decorated by"
    FLAVOUR ||--o{ ORDER_FLAVOUR : "used in"

    BRANCH {
        int      branch_id PK
        text     name
        text     city
        text     address
    }
    DAILY_CAPACITY {
        int      branch_id PK,FK
        date     cap_date PK
        int      max_units
    }
    CUSTOMER {
        int      customer_id PK
        text     first_name
        text     last_name
        text     phone
        text     email
        text     city
    }
    CAKE_TYPE {
        int      cake_type_id PK
        text     name            "birthday|wedding|graduation|corporate"
        numeric  base_price_ngn
    }
    FLAVOUR {
        int      flavour_id PK
        text     name
        numeric  surcharge_ngn
    }
    CAKE_ORDER {
        int      order_id PK
        int      branch_id FK
        int      customer_id FK
        int      cake_type_id FK
        date     order_date
        date     due_date
        int      tiers              "1..5"
        text     size_code          "S|M|L|XL"
        numeric  unit_price_ngn
        text     status              "PENDING..DELIVERED|CANCELLED"
        text     fulfillment_mode   "pickup|delivery"
    }
    ORDER_FLAVOUR {
        int      order_id PK,FK
        int      flavour_id PK,FK
        int      tier_no PK          "1..tiers"
    }
    PAYMENT {
        int      payment_id PK
        int      order_id FK
        numeric  amount_ngn
        timestamptz paid_at
        text     kind                "deposit|balance"
        text     method              "card|transfer|cash|pos"
    }
    DECORATOR_ASSIGNMENT {
        int      assignment_id PK
        int      decorator_id PK
        int      branch_id FK
        int      order_id FK
        tstzrange decorating_window
        text     status
    }
```

## Cardinality summary

- A **branch** has one `daily_capacity` row per date (composite PK).
- A **cake_order** belongs to exactly one branch and one customer.
- `order_flavour` resolves the many-to-many between `cake_order` and
  `flavour`, with one flavour per tier (the tier number is part of the PK).
- A `decorator_assignment` maps one decorator to one order over a
  `tstzrange` window; overlapping windows for the same decorator are
  forbidden by a `btree_gist` EXCLUDE constraint (P1 constraint b).
- A `payment` is either a `deposit` or a `balance` row on an order.

## Constraint legend (mapped to SQL in `schema.sql` / `constraints.sql`)

| Tag | Constraint |
| --- | --- |
| C1 | `daily_capacity` cannot be exceeded by cake units on a due date (trigger `trg_check_capacity`) — 1 tier = 1 unit, so a 3-tier cake = 3 units. |
| C2 | `decorator_assignment` windows cannot overlap per decorator (EXCLUDE USING `btree_gist`). |
| C3 | `due_date >= order_date + 2` (CHECK on `cake_order`). |
| C4 | Deposit ≥ 50% of `unit_price_ngn` before status can become `CONFIRMED` (trigger `trg_deposit_before_confirm`). |
| C5 | `tiers BETWEEN 1 AND 5`; `unit_price_ngn > 0`; `amount_ngn > 0`; `max_units > 0`. |
| C6 | Status transition follows `PENDING → CONFIRMED → BAKING → DECORATING → READY → COLLECTED|DELIVERED`, or `CANCELLED` (trigger `trg_status_fsm`). |
