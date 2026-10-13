const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// GET /planes — список з пошуком і сортуванням
app.get("/planes", async (req, res) => {
  try {
    let sql = "SELECT * FROM planes";
    const params = [];
    const conditions = [];

    if (req.query.search) {
      conditions.push(`name ILIKE $${params.length + 1}`);
      params.push(`%${req.query.search}%`);
    }

    if (conditions.length > 0) {
      sql += " WHERE " + conditions.join(" AND ");
    }

    if (req.query.sort === "passengers") {
      sql += " ORDER BY passengers ASC";
    } else {
      sql += " ORDER BY id ASC";
    }

    const result = await pool.query(sql, params);
    const totalPassengers = result.rows.reduce(
      (sum, p) => sum + p.passengers,
      0
    );

    res.json({
      total: result.rows.length,
      totalPassengers,
      data: result.rows,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// POST /planes — створити
app.post("/planes", async (req, res) => {
  try {
    const { name, fuelCapacity, passengers } = req.body;
    const result = await pool.query(
      "INSERT INTO planes (name, fuel_capacity, passengers) VALUES ($1, $2, $3) RETURNING *",
      [name, fuelCapacity, passengers]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// PUT /planes/:id — оновити
app.put("/planes/:id", async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const { name, fuelCapacity, passengers } = req.body;
    const result = await pool.query(
      "UPDATE planes SET name = $1, fuel_capacity = $2, passengers = $3 WHERE id = $4 RETURNING *",
      [name, fuelCapacity, passengers, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Not found" });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// DELETE /planes/:id — видалити
app.delete("/planes/:id", async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const result = await pool.query(
      "DELETE FROM planes WHERE id = $1 RETURNING *",
      [id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Not found" });
    }
    res.json({ success: true, deleted: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// Health check (знадобиться для ALB в завданні 4)
app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));