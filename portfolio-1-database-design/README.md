# Portfolio 1 — Database Design & Modelling

**Demonstrates:** ER model, 3NF schema, integrity constraints, triggers, EXCLUDE on `tstzrange`, bulk data generation.

**Course-note study sessions:** 1 (DB overview) · 2 (ER/EER) · 3 (relational mapping) · 4 (normalisation 1NF–BCNF) · 5 (constraints, triggers, stored procedures).

## Files

| File | Purpose |
| --- | --- |
| `er_diagram.md` | ER diagram in Mermaid + cardinality notes (renders on GitHub). |
| `3nf_notes.md` | Per-table 1NF/2NF/3NF/BCNF justification. |
| `schema.sql` | 9 tables in 3NF, FKs, base indexes. |
| `constraints.sql` | C1 capacity trigger, C2 EXCLUDE on `tstzrange`, C4 deposit≥50% trigger, C6 status FSM trigger. C3/C5 are CHECK constraints inside `schema.sql`. |
| `seed_data.sql` | 4 branches, 4 cake types, 8 flavours, `daily_capacity` for 730 days of history + the next 60 days. |
| `bulk_generator.sql` | 50k+ orders: 716 days of history + the next 14 days (Dec / Valentine / wedding peaks), NGN prices, payments, decorator assignments. |
| `constraint_tests.sql` | 8 tests; each builds its own situation and prints `TEST n PASS` when the database refuses it. |

## Run in Codespaces

```bash
bash run_p1.sh
```

## What to screenshot for evidence

1. The "Inserted N cake orders" notice + the bulk-generator stats table.
2. The "over-capacity days (must be 0)" row returning `0`.
3. The 8 `TEST n PASS` lines (each shows the SQLSTATE and message that refused the change).
4. The ER diagram rendering on GitHub (`er_diagram.md`).

## Git commit

```bash
git add portfolio-1-database-design/
git commit -m "P1: ER diagram, 3NF schema, triggers, EXCLUDE, bulk data, constraint tests"
```

## What this portfolio demonstrates

A complete 3NF schema for SweetCrust Bakery with nine tables, four
constraint mechanisms (CHECK, FK, EXCLUDE on a `tstzrange` using
`btree_gist`, and three BEFORE-triggers), 50k+ realistic orders across two
years with Nigerian names and ₦ prices, and eight executable tests proving
every constraint actually fires.
