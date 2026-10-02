import cors from "cors";
import express from "express";
import { config } from "./config";
import { pool, safeDbMessage } from "./db";
import { errorHandler } from "./middleware/errorHandler";
import { adminRouter } from "./routes/admin";
import { authRouter } from "./routes/auth";
import { gamesRouter } from "./routes/games";
import { playerRouter } from "./routes/player";

export function createApp() {
  const app = express();
  app.disable("x-powered-by");
  app.use(express.json({ limit: "32kb" }));
  app.use(
    cors({
      origin: config.CORS_ORIGIN === "*" ? true : config.CORS_ORIGIN.split(",").map((value) => value.trim()),
    }),
  );

  app.get("/api/health", async (_req, res) => {
    try {
      await pool.query("SELECT 1");
      res.json({ status: "ok", database: "connected" });
    } catch (error) {
      console.error(safeDbMessage(error));
      res.status(503).json({ status: "error", database: "unavailable" });
    }
  });
  app.use("/api/auth", authRouter);
  app.use("/api/admin", adminRouter);
  app.use("/api/player", playerRouter);
  app.use("/api/games", gamesRouter);
  app.use(errorHandler);
  return app;
}
