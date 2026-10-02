import { Router } from "express";
import { z } from "zod";
import { AppError } from "../errors";
import { asyncHandler } from "../middleware/asyncHandler";
import { authenticate } from "../middleware/authenticate";
import { requireRole } from "../middleware/requireRole";
import {
  adjustCredits,
  createPlayer,
  getUser,
  listActivity,
  listPlayers,
  listTransactions,
  updatePlayer,
} from "../services/userService";

export const adminRouter = Router();

adminRouter.use(authenticate, requireRole("ADMIN"));

const createSchema = z.object({
  username: z
    .string()
    .trim()
    .min(3)
    .max(32)
    .regex(/^[a-zA-Z0-9_]+$/, "Username can use letters, numbers, and underscores."),
  email: z.string().trim().email("Enter a valid email."),
  password: z.string().min(8, "Password must be at least 8 characters."),
  displayName: z.string().trim().min(1).max(60),
  startingCredits: z.number().int().min(0).max(1_000_000).default(0),
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
  amount: z.number().int().positive("Enter a credit amount greater than 0."),
  action: z.enum(["add", "remove"]),
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
      displayName: body.displayName,
      startingCredits: body.startingCredits ?? 0,
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

adminRouter.post(
  "/users/:id/credits",
  asyncHandler(async (req, res) => {
    const body = parse(creditSchema, req.body);
    const result = await adjustCredits({
      userId: param(req.params.id),
      adminId: req.authUser!.id,
      amount: body.amount,
      action: body.action,
    });
    res.json(result);
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
