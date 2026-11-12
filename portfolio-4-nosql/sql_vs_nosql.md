# Portfolio 4 — SQL vs NoSQL for SweetCrust Design Specs

SweetCrust's **cake_order** data is highly relational (branches, customers,
cake types, payments, decorator assignments) and is a great fit for the
3NF PostgreSQL schema in Portfolio 1. The **cake design specs**, on the
other hand — what colour each tier is, what toppers go on top, what
inscription, what fondant figures, what reference photos the customer
emailed in, and what allergy notes apply — are semi-structured and
**polymorphic by occasion**:

- A wedding design has 3–5 tiers, each with its own colour, filling and
  coating, plus a `fondant_figures` array and often a per-tier
  `inscription`.
- A corporate cake has a `logo_text`, sometimes a figurine mascot, and
  almost always at least one `reference_photos` URL.
- A birthday cake may have a child-character theme and a single tier
  with one inscription.

In pure 3NF SQL this would force **at least 4 extra tables**
(`design`, `tier_spec`, `topper`, `fondant_figure`) plus another
`reference_photo` table, with the resulting JOIN cost on every read of a
full design. The exact same design fits one MongoDB document:

```json
{
  "design_id": 1007,
  "occasion": "wedding",
  "branch_id": 2,
  "theme": "White Rose",
  "tiers": [
    { "tier_no": 1, "size_code": "L", "sponge_flavour": "vanilla",
      "filling": "buttercream", "colour": "#FFFFFF", "coating": "fondant" },
    { "tier_no": 2, "size_code": "M", "sponge_flavour": "red velvet",
      "filling": "cream cheese", "colour": "#FFB6C1", "coating": "fondant",
      "inscription": "Bola & Bayo" }
  ],
  "toppers": [ { "kind": "flowers", "qty": 12, "colour": "#FFB6C1" } ],
  "fondant_figures": [ { "name": "bride and groom", "qty": 1 } ],
  "reference_photos": [ { "url": "https://cdn.sweetcrust.example/refs/photo-1.jpg",
                          "label": "customer reference" } ],
  "allergy_notes": ["contains nuts","gluten-free"],
  "created_at": ISODate("2026-11-08T09:00:00Z")
}
```

## Comparison table

| Dimension | SQL (3NF PostgreSQL) | NoSQL (MongoDB) | SweetCrust implication |
| --- | --- | --- | --- |
| Data shape | Strict, normalised tables with FKs | Flexible, polymorphic documents | Designs vary per occasion; MongoDB avoids 4+ tables. |
| Schema enforcement | Column types + CHECK + FK + triggers | `$jsonSchema` validator + `validationAction:'error'` | Both can enforce "tiers 1..5, occasion enum", but SQL enforces more (FK to cake_order). |
| Read pattern for one design | 4–5 JOINs across design/tier/topper/photo tables | Single document fetch by `_id` or `order_id` | MongoDB reads are O(1) round trips; SQL reads need a query planner. |
| Write pattern | Multiple inserts + transaction | One document insert | MongoDB is faster for the design write; SQL gives ACID across design+order. |
| Cross-document consistency | Strong (FK, triggers) | Per-document atomic; no FK to SQL | If a design's `order_id` is deleted in SQL, MongoDB keeps a dangling doc — application must clean up. |
| Aggregation | SQL GROUP BY (Portfolio 2) | Aggregation pipeline `$unwind` + `$group` | Both work; MongoDB is more natural for nested arrays (`$unwind` on `tiers`). |
| Schema evolution | Migration scripts needed (add column, backfill) | Add a field, default to absent | SweetCrust adds new occasions/toppers often; MongoDB absorbs them. |
| Horizontal scaling | Hard (Portfolio 5 shows partitioning + replication) | Built-in sharding by `sh.shardCollection` | MongoDB is the easier scale-out path for design reads. |
| Query language | SQL (declarative, mature) | MQL + aggregation pipeline | Reporting teams prefer SQL; frontend devs often prefer MQL. |
| Storage cost | Normalised = less duplication, but more index overhead | Some duplication (e.g. occasion name repeated per doc) | Designs are read-heavy, write-light, so duplication is fine. |

## Decision

- The **operational, transactional** data (orders, payments, capacity,
  decorator assignments) stays in PostgreSQL — it needs ACID, FKs, triggers
  and the exclusion constraint on `tstzrange`. (Portfolios 1–3.)
- The **design specs** — the polymorphic, semi-structured, frequently
  evolving "what does the cake actually look like" data — lives in
  MongoDB as the `designs` collection. It is joined to PostgreSQL by the
  `order_id` foreign reference (stored on both sides, validated only on
  the SQL side as a real FK).
- This is the textbook "polyglot persistence" pattern: SQL for the
  transactional core, document store for the polymorphic descriptive data.
