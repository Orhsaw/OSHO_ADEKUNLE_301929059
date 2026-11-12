// =====================================================================
// Portfolio 4 — aggregations.js
// Three aggregation pipelines on the designs collection:
//   A1 most requested themes per occasion
//   A2 common allergy notes
//   A3 popular colours per occasion (unwind tiers)
//
// Run AFTER seed_designs.js:
//   mongosh sweetcrust_designs portfolio-4-nosql/aggregations.js
// =====================================================================

db = db.getSiblingDB('sweetcrust_designs');

print('\n===== A1: most requested themes per occasion =====');
const a1 = db.designs.aggregate([
  { $group: {
      _id: { occasion: '$occasion', theme: '$theme' },
      count: { $sum: 1 }
  }},
  { $sort: { '_id.occasion': 1, count: -1 } },
  { $group: {
      _id: '$_id.occasion',
      top_themes: { $push: { theme: '$_id.theme', count: '$count' } }
  }},
  { $project: { _id: 0, occasion: '$_id', top_themes: { $slice: ['$top_themes', 5] } } },
  { $sort: { occasion: 1 } }
]).toArray();
printjson(a1);

print('\n===== A2: common allergy notes =====');
const a2 = db.designs.aggregate([
  { $unwind: '$allergy_notes' },
  { $group: {
      _id: '$allergy_notes',
      designs: { $sum: 1 }
  }},
  { $sort: { designs: -1 } }
]).toArray();
printjson(a2);

print('\n===== A3: popular colours per occasion =====');
const a3 = db.designs.aggregate([
  { $unwind: '$tiers' },
  { $group: {
      _id: { occasion: '$occasion', colour: '$tiers.colour' },
      uses: { $sum: 1 }
  }},
  { $sort: { '_id.occasion': 1, uses: -1 } },
  { $group: {
      _id: '$_id.occasion',
      top_colours: { $push: { colour: '$_id.colour', uses: '$uses' } }
  }},
  { $project: { _id: 0, occasion: '$_id', top_colours: { $slice: ['$top_colours', 5] } } },
  { $sort: { occasion: 1 } }
]).toArray();
printjson(a3);

print('\n===== Bonus A4: average tier count per occasion =====');
const a4 = db.designs.aggregate([
  { $project: { occasion: 1, n_tiers: { $size: '$tiers' } } },
  { $group: { _id: '$occasion', avg_tiers: { $avg: '$n_tiers' }, n: { $sum: 1 } } },
  { $sort: { _id: 1 } }
]).toArray();
printjson(a4);
