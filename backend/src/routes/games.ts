import { Router } from "express";
import { z } from "zod";
import { AppError } from "../errors";
import { asyncHandler } from "../middleware/asyncHandler";
import { authenticate } from "../middleware/authenticate";
import { requireRole } from "../middleware/requireRole";
import { spin } from "../services/slotService";

export const gamesRouter = Router();

const spinSchema = z.object({
  betAmount: z.number().int().positive("Enter a valid bet."),
  choice: z.union([z.string().max(20), z.number().int().min(0).max(20)]).optional(),
  requestId: z.string().min(8).max(80).optional(),
});

gamesRouter.post(
  "/:gameId/spin",
  authenticate,
  requireRole("PLAYER"),
  asyncHandler(async (req, res) => {
    const body = spinSchema.safeParse(req.body);
    if (!body.success) {
      throw new AppError(400, body.error.issues[0]?.message ?? "Enter a valid bet.");
    }
    const gameId = Array.isArray(req.params.gameId) ? req.params.gameId[0] : req.params.gameId;
    if (!gameId) {
      throw new AppError(400, "Missing game id.");
    }
    const outcome = await spin(
      req.authUser!.id,
      gameId,
      body.data.betAmount,
      body.data.choice,
      body.data.requestId,
    );
    res.json(outcome);
  }),
);
