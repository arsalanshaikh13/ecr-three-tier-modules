const dbConfigPromise = require("./DbConfig");
const mysql = require("mysql2/promise");
require("dotenv").config();

// Use a pool rather than a single shared connection so concurrent requests and
// reconnect scenarios are handled more safely in ECS.
const dbPromise = (async () => {
  try {
    const dbcreds = await dbConfigPromise;

    // This replaced the old single connection setup that could become a bottleneck
    // or fail under concurrent request load.
    const pool = mysql.createPool({
      host: dbcreds.DB_HOST,
      user: dbcreds.DB_USER,
      password: dbcreds.DB_PASSWORD,
      database: dbcreds.DB_DATABASE,
      port: dbcreds.DB_PORT,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
    });

    // Validate connectivity during startup so app bootstrap fails early if DB is unreachable.
    await pool.query("SELECT 1");
    console.log("Connected to database pool!");

    return pool;
  } catch (err) {
    console.error("Failed to initialize DB pool:", err);
    throw err;
  }
})();

module.exports = dbPromise;
