import { Router } from "express";
import { z } from "zod";
import { AppError } from "../errors";
import { asyncHandler } from "../middleware/asyncHandler";
import { authenticate } from "../middleware/authenticate";
import { login, registerPlayer } from "../services/authService";
import { getOwnProfile } from "../services/userService";

export const authRouter = Router();

const registerSchema = z
  .object({
    username: z
      .string()
      .trim()
      .min(3, "Username must be at least 3 characters.")
      .max(32)
      .regex(/^[a-zA-Z0-9_]+$/, "Username can use letters, numbers, and underscores."),
    email: z.string().trim().email("Enter a valid email."),
    password: z.string().min(8, "Password must be at least 8 characters."),
    confirmPassword: z.string().min(1, "Confirm your password."),
    displayName: z.string().trim().min(1).max(60).optional(),
    role: z.string().optional(),
  })
  .refine((value) => value.password === value.confirmPassword, {
    message: "Passwords do not match.",
    path: ["confirmPassword"],
  });

const loginSchema = z.object({
  username: z.string().trim().min(1, "Username is required."),
  password: z.string().min(1, "Password is required."),
});

authRouter.post(
  "/register",
  asyncHandler(async (req, res) => {
    const body = parse(registerSchema, req.body);
    if (body.role && body.role !== "PLAYER") {
      throw new AppError(400, "A player account cannot register as an admin.");
    }
    const user = await registerPlayer({
      username: body.username,
      email: body.email,
      password: body.password,
      displayName: body.displayName,
    });
    res.status(201).json({ user });
  }),
);

authRouter.post(
  "/login",
  asyncHandler(async (req, res) => {
    const body = parse(loginSchema, req.body);
    const session = await login(body.username, body.password);
    res.json(session);
  }),
);

authRouter.get(
  "/me",
  authenticate,
  asyncHandler(async (req, res) => {
    const authUser = req.authUser!;
    if (authUser.role === "PLAYER") {
      const profile = await getOwnProfile(authUser.id);
      res.json({ user: { id: authUser.id, username: authUser.username, role: authUser.role }, profile });
      return;
    }
    res.json({ user: { id: authUser.id, username: authUser.username, role: authUser.role } });
  }),
);

function parse<T>(schema: z.ZodType<T>, body: unknown): T {
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    throw new AppError(400, parsed.error.issues[0]?.message ?? "Invalid request.");
  }
  return parsed.data;
}
