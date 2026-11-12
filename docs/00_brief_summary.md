# MIT 8103 — Continuous Assessment Brief Summary

**Student:** Adekunle Osho · **Matric:** 2026/A/MIT/0802
**Programme:** Master of Information Technology, Miva Open University
**Course:** MIT 8103 — Advanced Database Systems (40 marks)
**Case study:** SweetCrust Bakery — custom cake orders across Lagos (Surulere, Lekki, Ikeja) and Ibadan (Bodija) branches.

## What the CA requires (from the question paper)

- **Assessment type:** Individual practical portfolio — 5 portfolios + a final 2–3 page documentation, 40 marks total.
- **Case study:** Each student selects one realistic organisation and uses it consistently across all five portfolios. SweetCrust Bakery is used here.
- **Deliverables per portfolio:** practical evidence (scripts, schemas, ER diagrams, NoSQL models, execution plans, screenshots/outputs) plus short READMEs.
- **GitHub repo (private):** must follow the suggested structure
  `advanced-database-portfolio/{portfolio-1..5}/` plus a top-level `README.md`.
  Progressive commits are required — bulk uploads at the deadline reduce marks.
- **LMS submission:** a 2–3 page documentation file describing the 5 portfolios, the chosen organisation, screenshots/evidence, individual reflection, references and an AI-use declaration. The repo must be accessible to the assessor before LMS submission.
- **Naming rules:** the documentation file is named
  `Osho_Adekunle_2026-A-MIT-0802_Documentation.pdf` and is produced **after** running everything, using only real results.
- **Submission rules:** LMS + GitHub. GitHub link goes in the documentation and in the top-level repo `README.md` (placeholder `[GitHub link]` until the student creates the repo).
- **AI use:** permitted as a learning aid, but must be declared (tool used, what for, how the output was reviewed/tested). AI does not remove the student's responsibility for accuracy and understanding.
- **Similarity / integrity:** individual work; copied or inaccessible submissions may trigger an individual verification discussion. Technical verification is mainly by submitted evidence + progressive commits, not a viva for every student.
- **Rubric (40):** technical correctness 8, design quality 6, practical implementation 8, query/perf analysis 5, advanced concepts 5, documentation & GitHub organisation 5, individual reflection 3.

## Portfolio → Course-note study session map

| Portfolio | Title | Course-note study sessions it applies |
| --- | --- | --- |
| P1 | Database Design & Modelling | Session 1: Database & DBMS overview · Session 2: ER/EER modelling · Session 3: Relational model & mapping · Session 4: Functional dependencies & normalisation (1NF–3NF, BCNF) · Session 5: Integrity constraints, triggers & stored procedures |
| P2 | Query Processing & Optimisation | Session 6: Relational algebra & SQL · Session 7: Query processing & execution plans · Session 8: Indexing (B-tree, Hash, GiST, GIN) · Session 9: Query optimisation (cost model, statistics, EXPLAIN ANALYZE) |
| P3 | Transactions & Concurrency | Session 10: Transaction management & ACID · Session 11: Concurrency control & isolation levels · Session 12: Locking, deadlocks & MVCC · Session 13: Recovery & log-based recovery |
| P4 | NoSQL & Advanced Data Models | Session 14: NoSQL data models (document, key-value, column, graph) · Session 15: MongoDB document model & schema validation · Session 16: Aggregation framework & indexing in NoSQL · Session 17: SQL vs NoSQL trade-offs |
| P5 | Distributed & Cloud Database | Session 18: Distributed DBMS architecture · Session 19: Replication (streaming, sync/async) · Session 20: Partitioning / sharding · Session 21: CAP & consistency models · Session 22: Cloud DB deployment, NDPA 2023 & data residency |

> The two uploaded PDFs are: (1) `Edited - MIT8103 Advanced Database Systems.pdf` — the course-note pack for the study sessions above; and (2) `mit-8103-advanced-database-systems-ca-september-cohort-2026.pdf` — the CA question paper. This summary distils only the CA requirements.
