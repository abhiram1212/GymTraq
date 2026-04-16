const { Pool, types } = require('pg');

// NUMERIC → JS float (pg returns NUMERIC as string by default; Swift Codable expects a number)
types.setTypeParser(1700, parseFloat);
// DATE → keep as plain "YYYY-MM-DD" string (pg converts DATE to a JS Date by default,
// which JSON-serialises to a full ISO timestamp like "2024-04-13T04:00:00.000Z")
types.setTypeParser(1082, (val) => val);

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

module.exports = pool;
