// =====================================================================
// Portfolio 4 — mongo_schema_validation.js
// MongoDB collection for SweetCrust cake DESIGN SPECS.
//
// Each design document is intentionally rich and irregular: tiers each
// have their OWN colours and fillings, toppers, inscriptions, fondant
// figures, reference photo links and allergy notes. Some designs have
// fields others don't (e.g. wedding cakes have a fondant figures array;
// corporate cakes have a logo_text field). This is exactly the kind of
// semi-structured, polymorphic-by-event data that MongoDB handles well
// and that is awkward to model in pure 3NF SQL.
//
// Run:
//   mongosh sweetcrust_designs portfolio-4-nosql/mongo_schema_validation.js
// =====================================================================

db = db.getSiblingDB('sweetcrust_designs');

db.designs.drop();

db.createCollection('designs', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['design_id', 'occasion', 'branch_id', 'customer_id',
                 'order_id', 'tiers', 'created_at', 'allergy_notes'],
      properties: {
        design_id:     { bsonType: 'long',   description: 'must be a long, links to cake_order.order_id' },
        occasion:      { enum: ['birthday','wedding','graduation','corporate'], description: 'cake occasion' },
        branch_id:     { bsonType: 'int',    description: 'SweetCrust branch_id 1..4' },
        customer_id:   { bsonType: 'int' },
        order_id:      { bsonType: 'int',    description: 'SQL cake_order.order_id this design belongs to' },
        theme:          { bsonType: 'string', description: 'free-text theme, e.g. "Frozen", "Super Eagles"' },
        tiers: {
          bsonType: 'array',
          minItems: 1,
          maxItems: 5,
          items: {
            bsonType: 'object',
            required: ['tier_no', 'size_code', 'sponge_flavour', 'colour'],
            properties: {
              tier_no:        { bsonType: 'int', minimum: 1, maximum: 5 },
              size_code:      { enum: ['S','M','L','XL'] },
              sponge_flavour: { bsonType: 'string' },
              filling:        { bsonType: 'string' },             // optional
              colour:         { bsonType: 'string' },             // hex like #FFB6C1
              coating:        { enum: ['buttercream','fondant','ganache','naked'] },
              inscription:    { bsonType: 'string' }              // optional, per-tier
            }
          }
        },
        toppers: {
          bsonType: 'array',
          items: {
            bsonType: 'object',
            required: ['kind'],
            properties: {
              kind:    { enum: ['candle','figurine','flowers','number','letter','monogram','logo'] },
              colour:  { bsonType: 'string' },
              text:    { bsonType: 'string' },     // optional
              qty:     { bsonType: 'int', minimum: 1 }
            }
          }
        },
        fondant_figures: {                          // only for wedding / corporate typically
          bsonType: 'array',
          items: {
            bsonType: 'object',
            required: ['name'],
            properties: {
              name:    { bsonType: 'string' },     // e.g. "bride and groom"
              qty:     { bsonType: 'int', minimum: 1 },
              colour:  { bsonType: 'string' }
            }
          }
        },
        inscription: { bsonType: 'string' },        // top-level inscription
        logo_text:   { bsonType: 'string' },         // corporate only
        reference_photos: {
          bsonType: 'array',
          items: {
            bsonType: 'object',
            required: ['url'],
            properties: {
              url:        { bsonType: 'string' },
              label:      { bsonType: 'string' },    // e.g. "customer reference"
              uploaded_by:{ bsonType: 'string' }
            }
          }
        },
        allergy_notes: {
          bsonType: 'array',
          items: { bsonType: 'string' }             // e.g. "contains nuts", "gluten-free"
        },
        created_at:  { bsonType: 'date' }
      }
    }
  },
  validationLevel: 'strict',
  validationAction: 'error'
});

print('==> designs collection created with $jsonSchema validator');

// NOTE: no extra indexes are created here on purpose. Only the default _id
// index exists, so the BEFORE plan in index_demo.js is a genuine COLLSCAN.
