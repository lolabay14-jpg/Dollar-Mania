import { Pool, type PoolConfig, type PoolClient } from "pg";
import { config } from "./config";

function poolConfig(connectionString: string): PoolConfig {
  const local = /@(localhost|127\.0\.0\.1)(:|\/)/i.test(connectionString);
  return {
    connectionString,
    ssl: local ? undefined : { rejectUnauthorized: false },
  };
}

export const pool = new Pool(poolConfig(config.DATABASE_URL));

pool.on("error", () => {
  console.error("Database connection lost.");
});

export async function withTransaction<T>(work: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await work(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch {
      console.error("Database rollback failed.");
    }
    throw error;
  } finally {
    client.release();
  }
}

export function safeDbMessage(error: unknown): string {
  const message = error instanceof Error ? error.message : "Database request failed.";
  return message.replace(/postgres(?:ql)?:\/\/\S+/gi, "[redacted]");
}
