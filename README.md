# Advanced Database Portfolio — MIT 8103

**Student:** Adekunle Osho · **Matric:** 2026/A/MIT/0802
**Programme:** Master of Information Technology, Miva Open University
**Course:** MIT 8103 — Advanced Database Systems
**Case study:** SweetCrust Bakery (custom cake orders across Lagos & Ibadan branches)

GitHub repository: **[GitHub link]**

## Repository layout

```
advanced-database-portfolio/
├── docs/
│   └── 00_brief_summary.md          # CA brief + portfolio → study session map
├── portfolio-1-database-design/
├── portfolio-2-query-optimisation/
├── portfolio-3-transactions-concurrency/
├── portfolio-4-nosql/
├── portfolio-5-distributed-cloud/
├── setup.sh                         # installs PostgreSQL 16 + MongoDB 8 in Codespaces
├── collect_results.sh               # gathers every run log into my_results.txt
├── CHANGES.md                       # bugs found and fixed before the first run
└── README.md                        # this file
```

## Provision the environment (Codespaces)

```bash
bash setup.sh
```

This installs PostgreSQL 16 + MongoDB 8 + the Python database driver, creates the
`sweetcrust` and `sweetcrust_p5` databases, enables `btree_gist`, and starts both
servers (no systemd in Codespaces: PostgreSQL via `pg_ctlcluster`, MongoDB via
`mongod --fork`).
Connect to PostgreSQL over the **Unix socket** (TCP needs a password):

```bash
sudo runuser -u postgres -- psql -d sweetcrust
mongosh sweetcrust_designs
```

## Running each portfolio

| Portfolio | Folder | Run | Demonstrates |
| --- | --- | --- | --- |
| 1 | `portfolio-1-database-design/` | `bash run_p1.sh` | ER model, 3NF schema, constraints, triggers, bulk data |
| 2 | `portfolio-2-query-optimisation/` | `bash run_p2.sh` | 6–8 queries + EXPLAIN ANALYZE before/after indexes |
| 3 | `portfolio-3-transactions-concurrency/` | `bash run_p3.sh` | `place_order()` tx, COMMIT/ROLLBACK, race condition + 2 fixes, isolation levels, deadlock (two real sessions, automated) |
| 4 | `portfolio-4-nosql/` | `bash run_p4.sh` | MongoDB design specs, schema validation, aggregations, index demo |
| 5 | `portfolio-5-distributed-cloud/` | `bash run_p5.sh` | Monthly partitioning of the real P1 data, streaming replica (automated), cloud architecture |

Run them in order 1 to 5 (P5 copies the data P1 generates). Each `run_pN.sh` saves
its own evidence log, so nothing has to be copied by hand. `collect_results.sh`
gathers all the logs into `my_results.txt`. See `CHANGES.md` for what was fixed
before the first real run.

## AI-use declaration

See the final documentation file
`Osho_Adekunle_2026-A-MIT-0802_Documentation.pdf` (produced after the
portfolio has been executed and verified) for the full AI-use declaration
and individual technical reflection.

## Honest-output policy

Every `[paste real output here]` placeholder in this repo must be replaced
with the actual output captured from running the script in Codespaces
before submission. No EXPLAIN plans, timings or screenshots are simulated.
