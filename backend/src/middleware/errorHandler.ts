import type { NextFunction, Request, Response } from "express";
import { safeDbMessage } from "../db";
import { AppError } from "../errors";

export function errorHandler(error: unknown, _req: Request, res: Response, _next: NextFunction) {
  if (error instanceof AppError) {
    res.status(error.status).json({ error: error.message });
    return;
  }

  console.error(safeDbMessage(error));
  res.status(500).json({ error: "Something went wrong." });
}
