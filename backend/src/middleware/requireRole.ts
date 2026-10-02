import type { NextFunction, Request, Response } from "express";
import { AppError } from "../errors";
import type { AuthUser } from "./authenticate";

export function requireRole(role: AuthUser["role"]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.authUser) {
      next(new AppError(401, "Missing token"));
      return;
    }
    if (req.authUser.role !== role) {
      next(new AppError(403, "You do not have access to this resource."));
      return;
    }
    next();
  };
}
