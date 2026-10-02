import { createApp } from "./app";
import { config } from "./config";
import { pool } from "./db";

const app = createApp();

const server = app.listen(config.PORT, () => {
  console.log(`Dollar Mania API listening on port ${config.PORT}`);
});

async function shutdown() {
  server.close();
  await pool.end();
}

process.on("SIGINT", () => {
  void shutdown();
});
process.on("SIGTERM", () => {
  void shutdown();
});
