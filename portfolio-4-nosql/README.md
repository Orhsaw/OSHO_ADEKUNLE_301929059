# Portfolio 4 — NoSQL & Advanced Data Models

**Demonstrates:** a MongoDB document collection for cake design specs, a strict `$jsonSchema` validator, 40,000+ documents generated in JS loops, three aggregation pipelines, and a measured COLLSCAN→IXSCAN index transformation.

**Course-note study sessions:** 14 (NoSQL data models: document / key-value / column / graph) · 15 (MongoDB document model & schema validation) · 16 (aggregation framework & indexing in NoSQL) · 17 (SQL vs NoSQL trade-offs / polyglot persistence).

## Files

| File | Purpose |
| --- | --- |
| `mongo_schema_validation.js` | Creates the `designs` collection with a `$jsonSchema` validator (`validationLevel: strict`, `validationAction: error`). Tiers, toppers, fondant figures, inscriptions, reference photos and allergy notes all live inside one document. |
| `seed_designs.js` | Deterministic LCG-seeded bulk insert of 40,000 design documents in batches of 1,000. Polymorphic by occasion (birthday / wedding / graduation / corporate). |
| `aggregations.js` | A1 most requested themes per occasion · A2 common allergy notes · A3 popular colours per occasion (via `$unwind` on `tiers`) · A4 average tier count per occasion. |
| `index_demo.js` | Drops any existing `(occasion, theme)` index (the collection has only `_id`, so the baseline is a real COLLSCAN), captures the COLLSCAN plan, creates the compound index, captures the IXSCAN plan, prints a comparison summary. |
| `index_before_after.md` | Where the real captured plan numbers go (`[paste real output here]`). |
| `sql_vs_nosql.md` | Polyglot-persistence rationale: SQL for the transactional core, MongoDB for the polymorphic design specs. |

## Run in Codespaces

```bash
bash run_p4.sh
```

## What to screenshot for evidence

1. The `designs` collection count = 40,000 from `seed_designs.log`.
2. The `perOccasion` breakdown array (4 occasions).
3. The 4 aggregation result arrays from `aggregations.log`.
4. The COLLSCAN winning plan BEFORE + the IXSCAN winning plan AFTER
   from `index_demo.log`, plus the summary table.

## Git commit

```bash
git add portfolio-4-nosql/
git commit -m "P4: MongoDB design specs, validator, 40k docs, aggregations, COLLSCAN->IXSCAN"
```

## What this portfolio demonstrates

A document-store slice of SweetCrust that complements the 3NF SQL
core: a strict `$jsonSchema` validator on the `designs` collection,
40,000 polymorphic-by-occasion design documents (tiers with their own
colours and fillings, toppers, inscriptions, fondant figures, reference
photos and allergy notes), three aggregation pipelines over nested
arrays, and a measured COLLSCAN→IXSCAN transformation with a comparison
table.
