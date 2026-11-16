const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");
const { createClient } = require("redis");
const swaggerUi = require("swagger-ui-express");
const swaggerDocument = require("./swagger.json");

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const redisClient = createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379'
});
redisClient.on('error', (err) => console.log('Redis Client Error', err));
redisClient.connect();

// GET /planes
app.get("/planes", async (req, res) => {
  try {
    const hasFilters = req.query.search || req.query.sort === "passengers";
    if (!hasFilters) {
      const cachedData = await redisClient.get('planes_list');
      if (cachedData) {
        console.log('CACHE HIT');
        return res.json(JSON.parse(cachedData));
      }
    }
    console.log('CACHE MISS');


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

    const responseData = {
      total: result.rows.length,
      totalPassengers,
      data: result.rows,
    };

    if (!hasFilters) {
      await redisClient.setEx('planes_list', 30, JSON.stringify(responseData));
    }
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

// POST /planes
app.post("/planes", async (req, res) => {
  try {
    const { name, fuelCapacity, passengers } = req.body;
    const result = await pool.query(
      "INSERT INTO planes (name, fuel_capacity, passengers) VALUES ($1, $2, $3) RETURNING *",
      [name, fuelCapacity, passengers]
    );

    await redisClient.del('planes_list');

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// PUT /planes/:id
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

    await redisClient.del('planes_list');

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// DELETE /planes/:id 
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

    await redisClient.del('planes_list');

    res.json({ success: true, deleted: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});
app.get("/version", (req, res) => {
  res.json({ version: "2.0", deployedBy: "GitHub Actions" });
});
app.use("/docs", swaggerUi.serve, swaggerUi.setup(swaggerDocument));
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));