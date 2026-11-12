// =====================================================================
// Portfolio 4 — index_demo.js
// Demonstrates the COLLSCAN -> IXSCAN transformation on the designs
// collection for the "all wedding designs with the White Rose theme"
// query.
//
// Run BEFORE the new index is created, capture the explain plan, then
// create the index, re-run the explain plan, and capture the IXSCAN
// version.
//
//   mongosh sweetcrust_designs portfolio-4-nosql/index_demo.js
// =====================================================================

db = db.getSiblingDB('sweetcrust_designs');

// Find the bottom stage of a plan (COLLSCAN or IXSCAN), whatever the explain format.
function leafStage(plan) {
  let p = plan.queryPlan || plan;
  while (p.inputStage) p = p.inputStage;
  return p.stage;
}

// =====================================================================
// Step 1: BEFORE — no index on (occasion, theme). The query plan
// should be a COLLSCAN.
// =====================================================================
print('\n===== BEFORE: explain() with NO index on (occasion, theme) =====');
print('Make sure you have NOT yet run the createIndex step below.');
print('Drop any old index if it exists:');
try { db.designs.dropIndex('idx_occasion_theme'); } catch (e) { print('  (no idx to drop)'); }

const beforePlan = db.designs.find({
  occasion: 'wedding',
  theme:    'White Rose'
}).explain('executionStats');

printjson(beforePlan.executionStats);
print('>> winning plan BEFORE:');
printjson(beforePlan.queryPlanner.winningPlan);
print('>> total docs examined BEFORE: '
  + beforePlan.executionStats.totalDocsExamined);
print('>> docs returned BEFORE:       '
  + beforePlan.executionStats.nReturned);
print('>> execution time ms BEFORE:   '
  + beforePlan.executionStats.executionTimeMillis);

// =====================================================================
// Step 2: create the compound index (occasion, theme).
// =====================================================================
print('\n===== Creating idx_occasion_theme =====');
db.designs.createIndex({ occasion: 1, theme: 1 }, { name: 'idx_occasion_theme' });

// =====================================================================
// Step 3: AFTER — the same query now uses IXSCAN.
// =====================================================================
print('\n===== AFTER: explain() with idx_occasion_theme =====');
const afterPlan = db.designs.find({
  occasion: 'wedding',
  theme:    'White Rose'
}).explain('executionStats');

printjson(afterPlan.executionStats);
print('>> winning plan AFTER:');
printjson(afterPlan.queryPlanner.winningPlan);
print('>> total docs examined AFTER: '
  + afterPlan.executionStats.totalDocsExamined);
print('>> docs returned AFTER:       '
  + afterPlan.executionStats.nReturned);
print('>> execution time ms AFTER:   '
  + afterPlan.executionStats.executionTimeMillis);

// =====================================================================
// Step 4: print a small summary table the student can paste into the
// before/after markdown.
// =====================================================================
print('\n========== COLLSCAN vs IXSCAN summary ==========');
print('| Metric                | BEFORE (COLLSCAN) | AFTER (IXSCAN)   |');
print('| ----------------------|-------------------|------------------|');
print('| leaf stage of plan    | '
  + leafStage(beforePlan.queryPlanner.winningPlan)
  + '                | '
  + leafStage(afterPlan.queryPlanner.winningPlan)
  + '                |');
print('| totalDocsExamined     | '
  + beforePlan.executionStats.totalDocsExamined
  + '                 | '
  + afterPlan.executionStats.totalDocsExamined
  + '                |');
print('| nReturned            | '
  + beforePlan.executionStats.nReturned
  + '                 | '
  + afterPlan.executionStats.nReturned
  + '                |');
print('| executionTimeMillis  | '
  + beforePlan.executionStats.executionTimeMillis
  + '                 | '
  + afterPlan.executionStats.executionTimeMillis
  + '                |');

print('\n>>> Replace the [paste real output here] placeholders in index_before_after.md');
print('>>> with the actual numbers printed above.');
