// =====================================================================
// Portfolio 4 — seed_designs.js
// Bulk-insert 40,000+ design documents for SweetCrust Bakery, using
// generate_series-style loops (no CSV / JSON data files shipped).
//
// Run AFTER mongo_schema_validation.js:
//   mongosh sweetcrust_designs portfolio-4-nosql/seed_designs.js
// =====================================================================

db = db.getSiblingDB('sweetcrust_designs');

const OCCASIONS = ['birthday','wedding','graduation','corporate'];
const FLAVOURS  = ['vanilla','chocolate','red velvet','carrot','coconut','lemon','pound cake','fruit cake'];
const COLOURS   = ['#FFB6C1','#F8C8DC','#FFF8E7','#A2D5C6','#B5D8EB','#E6B89C','#D9BF77','#F4A7B9','#7FB069','#C03A2B'];
const COATINGS  = ['buttercream','fondant','ganache','naked'];
const THEMES    = {
  birthday:   ['Frozen','Spiderman','Barbie','Princess','Paw Patrol','Lion King','Football','Mermaid','Unicorn','Avengers'],
  wedding:    ['White Rose','Gold Leaf','Lace & Pearl','Tropical Floral','Naked Floral','Black & Gold','Pastel Garden','Royal Blue'],
  graduation: ['Navy & Gold','Faculty Colours','Cap & Scroll','Mortarboard'],
  corporate: ['TechCrunch','Bank Logo','Telco Brand','Government Agency']
};
const TOPPER_KINDS = ['candle','figurine','flowers','number','letter','monogram','logo'];
const ALLERGENS   = ['contains nuts','gluten-free','dairy-free','egg-free','contains alcohol','sugar-free','vegan'];

// Pre-generate pickers seeded with a fixed Math.random for reproducibility.
// We override Math.random with a deterministic LCG so re-runs match.
let __seed = 20260901n;
Math.random = function() {
  __seed = (1664525n * __seed + 1013904223n) % 4294967296n;
  return Number(__seed) / 4294967296;
};

function pick(arr)        { return arr[Math.floor(Math.random() * arr.length)]; }
function pickSome(arr,k) {
  const out = new Set();
  while (out.size < k && out.size < arr.length) {
    out.add(arr[Math.floor(Math.random() * arr.length)]);
  }
  return Array.from(out);
}
function randInt(min,max) { return Math.floor(Math.random()*(max-min+1))+min; }

function stripUndefined(v) {
  if (Array.isArray(v)) return v.map(stripUndefined);
  if (v && typeof v === 'object' && v.constructor === Object) {
    const out = {};
    Object.keys(v).forEach(k => { if (v[k] !== undefined) out[k] = stripUndefined(v[k]); });
    return out;
  }
  return v;
}

// Build a single design document for a given (orderId, occasion).
function makeDesign(orderId, occasion) {
  const branchId   = randInt(1,4);
  const customerId  = randInt(1,5000);
  const tiersCount  = occasion === 'wedding' ? randInt(3,5)
                   : occasion === 'corporate' ? randInt(1,3)
                   : randInt(1,3);
  const tiers = [];
  for (let i=1; i<=tiersCount; i++) {
    tiers.push({
      tier_no:        i,
      size_code:      pick(['S','M','L','XL']),
      sponge_flavour: pick(FLAVOURS),
      filling:        pick(['buttercream','cream cheese','chocolate ganache','jam','none']),
      colour:         pick(COLOURS),
      coating:        pick(COATINGS),
      inscription:    Math.random() < 0.4 ? `Tier ${i} text` : undefined
    });
  }

  // Toppers: 0-4 per design.
  const toppers = [];
  const tk = randInt(0,4);
  for (let i=0; i<tk; i++) {
    toppers.push({
      kind:   pick(TOPPER_KINDS),
      colour: pick(COLOURS),
      text:   Math.random() < 0.5 ? 'text' + randInt(1,99) : undefined,
      qty:    randInt(1,3)
    });
  }

  // Fondant figures: wedding + corporate typically.
  let fondant_figures;
  if (occasion === 'wedding' || (occasion === 'corporate' && Math.random() < 0.5)) {
    const fk = randInt(1,3);
    fondant_figures = [];
    for (let i=0; i<fk; i++) {
      fondant_figures.push({
        name:   pick(['bride and groom','anniversary couple','company logo','mascot','initials']),
        qty:    randInt(1,2),
        colour: pick(COLOURS)
      });
    }
  }

  const design = {
    design_id:    Long.fromNumber(orderId),
    occasion:     occasion,
    branch_id:    NumberInt(branchId),
    customer_id:  NumberInt(customerId),
    order_id:     NumberInt(orderId),
    theme:         pick(THEMES[occasion]),
    tiers:         tiers,
    toppers:       toppers,
    fondant_figures,
    inscription:   Math.random() < 0.6 ? `Happy ${occasion}!` : undefined,
    logo_text:     occasion === 'corporate' ? 'SweetCrust Corp' : undefined,
    reference_photos: pickSome([
      'https://cdn.sweetcrust.example/refs/photo-1.jpg',
      'https://cdn.sweetcrust.example/refs/photo-2.jpg',
      'https://cdn.sweetcrust.example/refs/photo-3.jpg',
      'https://cdn.sweetcrust.example/refs/photo-4.jpg',
      'https://cdn.sweetcrust.example/refs/photo-5.jpg'
    ], randInt(1,3)).map(url => ({ url, label: 'customer reference', uploaded_by: 'customer' })),
    allergy_notes: pickSome(ALLERGENS, randInt(1,3)),
    created_at:    new Date()
  };
  // Strip undefined values at EVERY level. The driver would store an
  // undefined field as null, and null fails the validator's bsonType 'string'.
  return stripUndefined(design);
}

// =====================================================================
// Insert 40,000 designs in batches of 1,000.
// We use orderId 1..40000 to keep the documents consistent.
// =====================================================================
const BATCH = 1000;
const TOTAL = 40000;
let inserted = 0;

for (let i = 1; i <= TOTAL; i += BATCH) {
  const docs = [];
  for (let j = 0; j < BATCH; j++) {
    const orderId = i + j;
    const occasion = OCCASIONS[orderId % 4];   // roughly equal mix
    docs.push(makeDesign(orderId, occasion));
  }
  db.designs.insertMany(docs, { ordered: false });
  inserted += docs.length;
  if (inserted % 5000 === 0) {
    print(`  inserted ${inserted}/${TOTAL}`);
  }
}

print(`==> Done. Inserted ${inserted} design documents.`);

// Sanity counts per occasion.
const perOccasion = db.designs.aggregate([
  { $group: { _id: '$occasion', n: { $sum: 1 } } },
  { $sort: { _id: 1 } }
]).toArray();
printjson(perOccasion);
