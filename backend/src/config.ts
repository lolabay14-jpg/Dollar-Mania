import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z
    .string()
    .min(1, "DATABASE_URL is missing from backend/.env")
    .refine((value) => /^postgres(?:ql)?:\/\//i.test(value), "DATABASE_URL must be a postgres connection string"),
  JWT_SECRET: z.string().min(16, "JWT_SECRET must be at least 16 characters"),
  PORT: z.coerce.number().int().positive().default(3000),
  CORS_ORIGIN: z.string().min(1).default("*"),
  DEFAULT_ADMIN_USERNAME: z.string().min(3).default("admin"),
  DEFAULT_ADMIN_PASSWORD: z.string().min(8),
  DEFAULT_PLAYER_USERNAME: z.string().min(3).default("player1"),
  DEFAULT_PLAYER_PASSWORD: z.string().min(8),
  DEFAULT_PLAYER2_USERNAME: z.string().min(3).default("player2"),
  DEFAULT_PLAYER2_PASSWORD: z.string().min(8),
  STARTING_CREDITS: z.coerce.number().int().positive().default(500),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  const message = parsed.error.issues.map((issue) => issue.message).join("; ");
  throw new Error(message);
}

export const config = parsed.data;
