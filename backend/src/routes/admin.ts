import { Router } from "express";
import { z } from "zod";
import { AppError } from "../errors";
import { asyncHandler } from "../middleware/asyncHandler";
import { authenticate } from "../middleware/authenticate";
import { requireRole } from "../middleware/requireRole";
import {
  countPendingCreditRequests,
  createCreditRequest,
  listCreditRequests,
  listOwnCreditRequests,
  reviewCreditRequest,
} from "../services/creditRequestService";
import { PROFILE_LEVELS } from "../services/gameParameters";
import { findPlayerForControls, listPlayerGameProfiles, setPlayerGameProfile } from "../services/gameProfileService";
import {
  findPlayerForAccess,
  listPlayerGameAccess,
  setAllPlayerGameAccess,
  setPlayerGameAccess,
} from "../services/playerGameAccessService";
import { getGameMode, setGameMode } from "../services/platformSettings";
import { listGamesForAdmin, setGameActive } from "../services/slotService";
import {
  adjustCredits,
  createAdmin,
  createPlayer,
  findUserByEmail,
  getAccountLedger,
  getAdminOverview,
  getPlayerHistory,
  getUser,
  listActivity,
  listPlayers,
  listRecentPlays,
  listStaff,
  listTransactions,
  setPlayerGameMode,
  setStaffActive,
  updatePlayer,
} from "../services/userService";

export const adminRouter = Router();

adminRouter.use(authenticate, requireRole("ADMIN", "SUPER_ADMIN"));

adminRouter.get(
  "/overview",
  asyncHandler(async (req, res) => {
    res.json(await getAdminOverview(req.authUser!.id));
  }),
);

adminRouter.get(
  "/staff",
  requireRole("SUPER_ADMIN"),
  asyncHandler(async (_req, res) => {
    const admins = await listStaff();
    res.json({ admins });
  }),
);

const staffSchema = z
  .object({
    username: z
      .string()
      .trim()
      .min(3, "Username must be at least 3 characters.")
      .max(32)
      .regex(/^[a-zA-Z0-9_]+$/, "Username can use letters, numbers, and underscores."),
    email: z.string().trim().email("Enter a valid email."),
    password: z.string().min(4, "Password must be at least 4 characters."),
    confirmPassword: z.string().min(1, "Confirm your password."),
    displayName: z.string().trim().min(1).max(60).optional(),
  })
  .refine((value) => value.password === value.confirmPassword, {
    message: "Passwords do not match.",
    path: ["confirmPassword"],
  });

adminRouter.post(
  "/staff",
  requireRole("SUPER_ADMIN"),
  asyncHandler(async (req, res) => {
    const body = parse(staffSchema, req.body);
    const user = await createAdmin({
      username: body.username,
      email: body.email,
      password: body.password,
      displayName: body.displayName ?? body.username,
      adminId: req.authUser!.id,
    });
    res.status(201).json({ user });
  }),
);

const staffAccessSchema = z.object({
  isActive: z.boolean(),
});

adminRouter.patch(
  "/staff/:id/access",
  requireRole("SUPER_ADMIN"),
  asyncHandler(async (req, res) => {
    const body = parse(staffAccessSchema, req.body);
    const user = await setStaffActive(req.authUser!.id, param(req.params.id), body.isActive);
    res.json({ user });
  }),
);

adminRouter.get(
  "/games",
  asyncHandler(async (_req, res) => {
    res.json({ games: await listGamesForAdmin() });
  }),
);

adminRouter.get(
  "/settings",
  asyncHandler(async (_req, res) => {
    res.json({
      gameMode: await getGameMode(),
      games: await listGamesForAdmin(),
    });
  }),
);

const modeSchema = z.object({
  gameMode: z.enum(["EASY", "MEDIUM", "HARD"]),
});

adminRouter.put(
  "/settings/mode",
  asyncHandler(async (req, res) => {
    const body = parse(modeSchema, req.body);
    res.json({ gameMode: await setGameMode(body.gameMode) });
  }),
);

const availabilitySchema = z.object({
  isActive: z.boolean(),
});

adminRouter.patch(
  "/games/:id",
  asyncHandler(async (req, res) => {
    const body = parse(availabilitySchema, req.body);
    res.json({ game: await setGameActive(param(req.params.id), body.isActive) });
  }),
);

adminRouter.get(
  "/plays",
  asyncHandler(async (_req, res) => {
    res.json({ plays: await listRecentPlays(40) });
  }),
);

const createSchema = z
  .object({
    username: z
      .string()
      .trim()
      .min(3, "Username must be at least 3 characters.")
      .max(32)
      .regex(/^[a-zA-Z0-9_]+$/, "Username can use letters, numbers, and underscores."),
    email: z.string().trim().email("Enter a valid email."),
    password: z.string().min(4, "Password must be at least 4 characters."),
    confirmPassword: z.string().min(1, "Confirm your password."),
    displayName: z.string().trim().min(1).max(60).optional(),
    startingCredits: z
      .number()
      .int("Starting credits must be a whole number.")
      .min(0)
      .max(1_000_000),
    role: z.string().optional(),
  })
  .refine((value) => value.password === value.confirmPassword, {
    message: "Passwords do not match.",
    path: ["confirmPassword"],
  })
  .refine((value) => value.role === undefined || value.role === "PLAYER", {
    message: "New accounts must be players.",
  });

const patchSchema = z
  .object({
    isActive: z.boolean().optional(),
    displayName: z.string().trim().min(1).max(60).optional(),
  })
  .refine((value) => value.isActive !== undefined || value.displayName !== undefined, {
    message: "Nothing to update.",
  });

const creditSchema = z.object({
  amount: z.number().int().positive("Enter a credit amount greater than 0.").max(1_000_000),
  action: z.enum(["add", "remove"]),
  note: z.string().trim().max(200).optional(),
  requestId: z.string().trim().min(8).max(80).optional(),
});

adminRouter.get(
  "/users",
  asyncHandler(async (_req, res) => {
    const users = await listPlayers();
    const credits = users.reduce((sum, user) => sum + user.balance, 0);
    res.json({ users, totalPlayers: users.length, totalCredits: credits });
  }),
);

adminRouter.get(
  "/users/search",
  asyncHandler(async (req, res) => {
    const parsed = z.string().trim().email("Enter a valid email.").safeParse(req.query.email);
    if (!parsed.success) {
      throw new AppError(400, parsed.error.issues[0]?.message ?? "Enter a valid email.");
    }
    res.json({ user: await findUserByEmail(parsed.data) });
  }),
);

adminRouter.get(
  "/users/player",
  asyncHandler(async (req, res) => {
    const parsed = z.string().trim().email("Enter a valid email.").safeParse(req.query.email);
    if (!parsed.success) {
      throw new AppError(400, parsed.error.issues[0]?.message ?? "Enter a valid email.");
    }
    res.json({ player: await findPlayerForControls(parsed.data) });
  }),
);

adminRouter.get(
  "/users/:id/ledger",
  requireRole("SUPER_ADMIN"),
  asyncHandler(async (req, res) => {
    res.json(await getAccountLedger(param(req.params.id)));
  }),
);

adminRouter.get(
  "/users/:id/history",
  asyncHandler(async (req, res) => {
    res.json(await getPlayerHistory(param(req.params.id)));
  }),
);

adminRouter.get(
  "/users/:id",
  asyncHandler(async (req, res) => {
    res.json({ user: await getUser(param(req.params.id)) });
  }),
);

adminRouter.post(
  "/users",
  asyncHandler(async (req, res) => {
    const body = parse(createSchema, req.body);
    const user = await createPlayer({
      username: body.username,
      email: body.email,
      password: body.password,
      displayName: body.displayName ?? body.username,
      startingCredits: body.startingCredits,
      adminId: req.authUser!.id,
    });
    res.status(201).json({ user });
  }),
);

adminRouter.patch(
  "/users/:id",
  asyncHandler(async (req, res) => {
    const body = parse(patchSchema, req.body);
    const user = await updatePlayer(param(req.params.id), req.authUser!.id, body);
    res.json({ user });
  }),
);

adminRouter.patch(
  "/users/:id/game-mode",
  asyncHandler(async (req, res) => {
    const body = parse(modeSchema, req.body);
    const user = await setPlayerGameMode(param(req.params.id), req.authUser!.id, body.gameMode);
    res.json({ user, message: "Game mode updated successfully." });
  }),
);

adminRouter.post(
  "/users/:id/credits",
  asyncHandler(async (req, res) => {
    const body = parse(creditSchema, req.body);
    const result = await adjustCredits({
      userId: param(req.params.id),
      adminId: req.authUser!.id,
      amount: body.amount,
      action: body.action,
      note: body.note,
      requestId: body.requestId,
    });
    res.json(result);
  }),
);

const profileSchema = z.object({
  profile: z.enum(PROFILE_LEVELS),
  parameters: z.record(z.number()).optional(),
});

adminRouter.get(
  "/users/:id/game-profiles",
  asyncHandler(async (req, res) => {
    res.json({ profiles: await listPlayerGameProfiles(param(req.params.id)) });
  }),
);

adminRouter.put(
  "/users/:id/game-profiles/:gameId",
  asyncHandler(async (req, res) => {
    const body = parse(profileSchema, req.body);
    const profile = await setPlayerGameProfile(
      req.authUser!.id,
      param(req.params.id),
      param(req.params.gameId),
      body.profile,
      body.parameters,
    );
    res.json({ profile });
  }),
);

adminRouter.get(
  "/game-access/search",
  requireRole("SUPER_ADMIN"),
  asyncHandler(async (req, res) => {
    const query = String(req.query.q ?? req.query.query ?? "").trim();
    const player = await findPlayerForAccess(query);
    const access = await listPlayerGameAccess(player.id);
    res.json(access);
  }),
);

adminRouter.get(
  "/users/:id/game-access",
  requireRole("SUPER_ADMIN"),
  asyncHandler(async (req, res) => {
    res.json(await listPlayerGameAccess(param(req.params.id)));
  }),
);

const gameAccessSchema = z.object({
  enabled: z.boolean(),
});

adminRouter.put(
  "/users/:id/game-access/:gameId",
  requireRole("SUPER_ADMIN"),
  asyncHandler(async (req, res) => {
    const body = parse(gameAccessSchema, req.body);
    const access = await setPlayerGameAccess(
      req.authUser!.id,
      param(req.params.id),
      param(req.params.gameId),
      body.enabled,
    );
    res.json(access);
  }),
);

adminRouter.put(
  "/users/:id/game-access",
  requireRole("SUPER_ADMIN"),
  asyncHandler(async (req, res) => {
    const body = parse(gameAccessSchema, req.body);
    const access = await setAllPlayerGameAccess(req.authUser!.id, param(req.params.id), body.enabled);
    res.json(access);
  }),
);

adminRouter.get(
  "/transactions",
  asyncHandler(async (_req, res) => {
    res.json({ transactions: await listTransactions() });
  }),
);

adminRouter.get(
  "/activity",
  asyncHandler(async (_req, res) => {
    res.json({ activity: await listActivity() });
  }),
);

adminRouter.get(
  "/credit-requests",
  asyncHandler(async (req, res) => {
    // ADMIN reviews PLAYER requests. SUPER_ADMIN reviews ADMIN requests.
    const audience = req.authUser!.role === "SUPER_ADMIN" ? "ADMIN" : "PLAYER";
    const statusRaw = String(req.query.status ?? "ALL").toUpperCase();
    const status =
      statusRaw === "PENDING" || statusRaw === "APPROVED" || statusRaw === "REJECTED" ? statusRaw : "ALL";
    const requests = await listCreditRequests(audience, status);
    const pendingCount = await countPendingCreditRequests(audience);
    res.json({ requests, pendingCount, audience });
  }),
);

adminRouter.get(
  "/credit-requests/pending-count",
  asyncHandler(async (req, res) => {
    const audience = req.authUser!.role === "SUPER_ADMIN" ? "ADMIN" : "PLAYER";
    const pendingCount = await countPendingCreditRequests(audience);
    res.json({ pendingCount, audience });
  }),
);

adminRouter.get(
  "/credit-requests/own",
  requireRole("ADMIN"),
  asyncHandler(async (req, res) => {
    res.json({ requests: await listOwnCreditRequests(req.authUser!.id) });
  }),
);

const createRequestSchema = z.object({
  amount: z.number().int().positive("Enter a credit amount.").max(1_000_000),
  note: z.string().trim().max(200).optional(),
});

adminRouter.post(
  "/credit-requests",
  requireRole("ADMIN"),
  asyncHandler(async (req, res) => {
    const body = parse(createRequestSchema, req.body);
    const request = await createCreditRequest(req.authUser!.id, body.amount, body.note ?? "");
    res.status(201).json({ request });
  }),
);

const reviewSchema = z.object({
  action: z.enum(["approve", "reject"]),
  note: z.string().trim().max(200).optional(),
});

adminRouter.post(
  "/credit-requests/:id/review",
  asyncHandler(async (req, res) => {
    const body = parse(reviewSchema, req.body);
    const role = req.authUser!.role === "SUPER_ADMIN" ? "SUPER_ADMIN" : "ADMIN";
    const result = await reviewCreditRequest(req.authUser!.id, role, param(req.params.id), body.action, body.note ?? "");
    res.json(result);
  }),
);

function param(value: string | string[]): string {
  const id = Array.isArray(value) ? value[0] : value;
  if (!id) {
    throw new AppError(400, "Missing user id.");
  }
  return id;
}

function parse<T>(schema: z.ZodType<T>, body: unknown): T {
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    throw new AppError(400, parsed.error.issues[0]?.message ?? "Invalid request.");
  }
  return parsed.data;
}
