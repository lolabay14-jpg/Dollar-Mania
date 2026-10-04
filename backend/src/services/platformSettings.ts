import type { PoolClient } from "pg";
import { pool } from "../db";
import { AppError } from "../errors";

export type GameMode = "EASY" | "MEDIUM" | "HARD";

export async function getGameMode(client?: PoolClient): Promise<GameMode> {
  const db = client ?? pool;
  const result = await db.query<{ value: string }>(
    "SELECT value FROM platform_settings WHERE key = 'game_mode'",
  );
  return asMode(result.rows[0]?.value);
}

export async function setGameMode(mode: string): Promise<GameMode> {
  const next = asMode(mode);
  if (next !== mode.toUpperCase()) {
    throw new AppError(400, "Choose Easy, Medium, or Hard.");
  }
  await pool.query(
    `INSERT INTO platform_settings (key, value)
     VALUES ('game_mode', $1)
     ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
    [next],
  );
  return next;
}

function asMode(value: string | undefined): GameMode {
  const next = String(value ?? "MEDIUM").toUpperCase();
  if (next === "EASY" || next === "HARD" || next === "MEDIUM") {
    return next;
  }
  return "MEDIUM";
}
