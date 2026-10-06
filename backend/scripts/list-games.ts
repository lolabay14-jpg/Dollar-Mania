import { pool } from "../src/db";

async function main() {
  const r = await pool.query(
    "SELECT name, slug, category, difficulty, is_active FROM slot_games ORDER BY name",
  );
  console.log(JSON.stringify(r.rows, null, 2));
  console.log("count", r.rows.length);
  await pool.end();
}

main().catch(async (error) => {
  console.error(error);
  await pool.end().catch(() => undefined);
  process.exit(1);
});
