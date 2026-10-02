import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { config } from "../config";
import { pool } from "../db";
import { AppError } from "../errors";

export type AuthUser = {
  id: string;
  username: string;
  role: "ADMIN" | "PLAYER";
  isActive: boolean;
};

declare global {
  namespace Express {
    interface Request {
      authUser?: AuthUser;
    }
  }
}

type TokenPayload = {
  sub?: string;
};

export async function authenticate(req: Request, _res: Response, next: NextFunction) {
  const header = req.header("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    next(new AppError(401, "Missing token"));
    return;
  }

  let userId = "";
  try {
    const payload = jwt.verify(match[1], config.JWT_SECRET) as TokenPayload;
    userId = payload.sub ?? "";
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      next(new AppError(401, "Session expired"));
      return;
    }
    next(new AppError(401, "Invalid token"));
    return;
  }

  if (!userId) {
    next(new AppError(401, "Invalid token"));
    return;
  }

  const result = await pool.query<{ id: string; username: string; role: "ADMIN" | "PLAYER"; is_active: boolean }>(
    "SELECT id, username, role, is_active FROM users WHERE id = $1",
    [userId],
  );
  const row = result.rows[0];
  if (!row) {
    next(new AppError(401, "Invalid token"));
    return;
  }
  if (!row.is_active) {
    next(new AppError(403, "Account is inactive"));
    return;
  }

  req.authUser = {
    id: row.id,
    username: row.username,
    role: row.role,
    isActive: row.is_active,
  };
  next();
}
