import { Router } from "express";
import { asyncHandler } from "../middleware/asyncHandler";
import { authenticate } from "../middleware/authenticate";
import { requireRole } from "../middleware/requireRole";
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
