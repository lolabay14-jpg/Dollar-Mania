import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { pool } from "../src/db";

async function migrate() {
  const directory = path.join(__dirname, "..", "migrations");
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id text PRIMARY KEY,
      applied_at timestamptz NOT NULL DEFAULT now()
    )
  `);

  const files = (await readdir(directory))
    .filter((file) => file.endsWith(".sql"))
    .sort();

  for (const file of files) {
    const existing = await pool.query("SELECT 1 FROM schema_migrations WHERE id = $1", [file]);
    if (existing.rowCount) {
      console.log(`Already applied ${file}`);
      continue;
    }
    const sql = await readFile(path.join(directory, file), "utf8");
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(sql);
      await client.query("INSERT INTO schema_migrations (id) VALUES ($1)", [file]);
      await client.query("COMMIT");
      console.log(`Applied ${file}`);
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }
}

migrate()
  .then(async () => {
    await pool.end();
    console.log("Migrations finished.");
  })
  .catch(async (error: unknown) => {
    const message = error instanceof Error ? error.message : "Migration failed.";
    console.error(message.replace(/postgres(?:ql)?:\/\/\S+/gi, "[redacted]"));
    await pool.end();
    process.exit(1);
  });
