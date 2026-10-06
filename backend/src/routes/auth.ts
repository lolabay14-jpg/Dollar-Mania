import { Router } from "express";
import { z } from "zod";
import { AppError } from "../errors";
import { asyncHandler } from "../middleware/asyncHandler";
import { authenticate } from "../middleware/authenticate";
import { changePassword, login } from "../services/authService";
import { getOwnProfile } from "../services/userService";

export const authRouter = Router();

const loginSchema = z.object({
  username: z.string().trim().min(1, "Username or email is required."),
  password: z.string().min(1, "Password is required."),
});

const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1, "Enter your current password."),
    newPassword: z.string().min(4, "Password must be at least 4 characters."),
    confirmPassword: z.string().min(1, "Confirm your new password."),
  })
  .refine((value) => value.newPassword === value.confirmPassword, {
    message: "New password and confirmation do not match.",
    path: ["confirmPassword"],
  });

authRouter.post("/register", (_req, res) => {
  res.status(403).json({ error: "Player accounts are created by an administrator." });
});

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

authRouter.post(
  "/change-password",
  authenticate,
  asyncHandler(async (req, res) => {
    const body = parse(changePasswordSchema, req.body);
    const result = await changePassword(req.authUser!.id, body.currentPassword, body.newPassword);
    res.json({ message: "Password updated successfully.", token: result.token });
  }),
);

function parse<T>(schema: z.ZodType<T>, body: unknown): T {
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    throw new AppError(400, parsed.error.issues[0]?.message ?? "Invalid request.");
  }
  return parsed.data;
}
