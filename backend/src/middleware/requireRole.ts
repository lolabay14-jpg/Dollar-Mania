import type { NextFunction, Request, Response } from "express";
import { AppError } from "../errors";
import type { AuthUser } from "./authenticate";

export function requireRole(...roles: AuthUser["role"][]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.authUser) {
      next(new AppError(401, "Missing token"));
      return;
    }
    if (!roles.includes(req.authUser.role)) {
      next(new AppError(403, "You do not have access to this resource."));
      return;
    }
    next();
  };
}
