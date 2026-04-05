const express = require("express");
const bodyParser = require("body-parser");
const routes = require("./routes");
const cors = require("cors");
const dbPromise = require("./configs/db");
const logger = require("./utils/logger"); // Import logger

const app = express();

app.use(cors());
app.use(bodyParser.json());

// App bootstrap should verify DB readiness before the server process starts listening.
// This keeps the app from serving requests while the DB pool is still unavailable.
(async () => {
  try {
    await dbPromise;
    logger.info("Database pool connected");
  } catch (err) {
    logger.error(`Failed to start: ${err.stack}`);
    process.exit(1);
  }
})();

/* Add your routes here */
// Health Checking
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "healthy",
    kind: "liveness",
    message: "Health check endpoint",
    timestamp: new Date().toISOString(),
  });
});

// Readiness is deeper than liveness: this verifies the app can still talk to the DB
// before smoke tests or internal traffic treat the backend as truly ready.
app.get("/readyz", async (req, res) => {
  try {
    const db = await dbPromise;
    await db.query("SELECT 1");

    return res.status(200).json({
      status: "ready",
      kind: "readiness",
      database: "reachable",
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    logger.error(`Readiness check failed: ${err.message}`);
    return res.status(503).json({
      status: "not-ready",
      kind: "readiness",
      database: "unreachable",
      message: "Database connectivity check failed.",
      timestamp: new Date().toISOString(),
    });
  }
});

app.use("/api", routes);

module.exports = app;
