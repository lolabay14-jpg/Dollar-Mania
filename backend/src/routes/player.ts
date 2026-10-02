import { Router } from "express";
import { z } from "zod";
import { AppError } from "../errors";
import { asyncHandler } from "../middleware/asyncHandler";
import { authenticate } from "../middleware/authenticate";
import { requireRole } from "../middleware/requireRole";
import { createCreditRequest, listOwnCreditRequests } from "../services/creditRequestService";
import { listActiveGames } from "../services/slotService";
import { getOwnProfile, getOwnSpins, getOwnTransactions, getOwnWallet } from "../services/userService";

export const playerRouter = Router();

playerRouter.use(authenticate, requireRole("PLAYER"));

playerRouter.get(
  "/profile",
  asyncHandler(async (req, res) => {
    res.json({ profile: await getOwnProfile(req.authUser!.id) });
  }),
);

playerRouter.get(
  "/wallet",
  asyncHandler(async (req, res) => {
    res.json(await getOwnWallet(req.authUser!.id));
  }),
);

playerRouter.get(
  "/transactions",
  asyncHandler(async (req, res) => {
    res.json({ transactions: await getOwnTransactions(req.authUser!.id) });
  }),
);

playerRouter.get(
  "/spins",
  asyncHandler(async (req, res) => {
    res.json({ spins: await getOwnSpins(req.authUser!.id) });
  }),
);

playerRouter.get(
  "/games",
  asyncHandler(async (_req, res) => {
    res.json({ games: await listActiveGames() });
  }),
);

const requestSchema = z.object({
  amount: z.number().int().positive("Enter a credit amount.").max(100_000),
});

playerRouter.get(
  "/credit-requests",
  asyncHandler(async (req, res) => {
    res.json({ requests: await listOwnCreditRequests(req.authUser!.id) });
  }),
);

playerRouter.post(
  "/credit-requests",
  asyncHandler(async (req, res) => {
    const parsed = requestSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new AppError(400, parsed.error.issues[0]?.message ?? "Enter a credit amount.");
    }
    const request = await createCreditRequest(req.authUser!.id, parsed.data.amount);
    res.status(201).json({ request });
  }),
);
