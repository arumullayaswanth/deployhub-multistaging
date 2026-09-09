const express = require("express");
const { pool } = require("./db");
const { register, metricsMiddleware } = require("./metrics");

function createApp() {
    const app = express();
    app.use(express.json());
    app.use(metricsMiddleware);

    // simple homepage so there's something to look at in the browser
    app.get("/", (_req, res) => {
        res.set("Content-Type", "text/html");
        res.status(200).send(`<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>DeployHub Sample App</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 640px; margin: 40px auto; padding: 0 16px; color: #1a1a1a; }
    h1 { margin-bottom: 4px; }
    .ok { color: #0a7d28; font-weight: 600; }
    ul { line-height: 2; }
    a { color: #1a5fb4; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .card { border: 1px solid #ddd; border-radius: 8px; padding: 16px 20px; margin-top: 20px; }
    button { background: #1a5fb4; color: #fff; border: 0; padding: 8px 14px; border-radius: 6px; cursor: pointer; }
    pre { background: #f5f5f5; padding: 12px; border-radius: 6px; overflow: auto; }
  </style>
</head>
<body>
  <h1>DeployHub Sample App</h1>
  <p class="ok">Status: running</p>

  <div class="card">
    <h3>Pages you can open</h3>
    <ul>
      <li><a href="/health">/health</a> - liveness check</li>
      <li><a href="/ready">/ready</a> - database connection check</li>
      <li><a href="/visits">/visits</a> - list rows from the database</li>
      <li><a href="/metrics">/metrics</a> - application metrics</li>
    </ul>
  </div>

  <div class="card">
    <h3>Add a visit (writes to the database)</h3>
    <input id="note" placeholder="type a note" style="padding:8px;width:60%">
    <button onclick="addVisit()">Add</button>
    <pre id="out">click "Add" to insert a row, then open /visits</pre>
  </div>

  <script>
    async function addVisit() {
      const note = document.getElementById('note').value || 'hello from the UI';
      const r = await fetch('/visits', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ note })
      });
      document.getElementById('out').textContent = JSON.stringify(await r.json(), null, 2);
    }
  </script>
</body>
</html>`);
    });

    // keep this cheap so the ALB health check doesn't fail on a db hiccup
    app.get("/health", (_req, res) => {
        res.status(200).json({ status: "ok" });
    });

    app.get("/ready", async (_req, res) => {
        try {
            await pool.query("SELECT 1");
            res.status(200).json({ status: "ready" });
        } catch (err) {
            res.status(503).json({ status: "not-ready", error: err.message });
        }
    });

    app.get("/metrics", async (_req, res) => {
        res.set("Content-Type", register.contentType);
        res.end(await register.metrics());
    });

    app.post("/visits", async (req, res) => {
        const note = (req.body && req.body.note) || "hello from deployhub";
        const result = await pool.query(
            "INSERT INTO visits (note) VALUES ($1) RETURNING id, note, created_at",
            [note]
        );
        res.status(201).json(result.rows[0]);
    });

    app.get("/visits", async (_req, res) => {
        const result = await pool.query(
            "SELECT id, note, created_at FROM visits ORDER BY id DESC LIMIT 20"
        );
        res.status(200).json(result.rows);
    });

    return app;
}

module.exports = { createApp };
