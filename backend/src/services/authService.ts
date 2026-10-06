import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { config } from "../config";
import { pool } from "../db";
import { AppError } from "../errors";
import type { AppRole } from "../middleware/authenticate";

const HASH_ROUNDS = 12;

export type PublicUser = {
  id: string;
  username: string;
  role: AppRole;
};

type UserRow = PublicUser & {
  password_hash: string;
  is_active: boolean;
};

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, HASH_ROUNDS);
}

export async function registerPlayer(input: {
  username: string;
  email: string;
  password: string;
  displayName?: string;
}) {
  const existing = await pool.query<{ username: string; email: string }>(
    "SELECT username, email FROM users WHERE username = $1 OR email = $2",
    [input.username, input.email],
  );
  if (existing.rows.some((row) => row.username === input.username)) {
    throw new AppError(409, "That username is already registered.");
  }
  if (existing.rows.some((row) => row.email === input.email)) {
    throw new AppError(409, "That email is already registered.");
  }

  const passwordHash = await hashPassword(input.password);
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const user = await client.query<{ id: string; username: string }>(
      `INSERT INTO users (username, email, password_hash, role)
       VALUES ($1, $2, $3, 'PLAYER')
       RETURNING id, username`,
      [input.username, input.email, passwordHash],
    );
    const created = user.rows[0];
    await client.query(
      `INSERT INTO player_profiles (user_id, display_name, avatar, level, experience)
       VALUES ($1, $2, NULL, 1, 0)`,
      [created.id, input.displayName?.trim() || input.username],
    );
    await client.query("INSERT INTO wallets (user_id, balance) VALUES ($1, 0)", [created.id]);
    await client.query("COMMIT");
    return { id: created.id, username: created.username, role: "PLAYER" as const };
  } catch (error) {
    await client.query("ROLLBACK");
    const code = typeof error === "object" && error && "code" in error ? String(error.code) : "";
    if (code === "23505") {
      throw new AppError(409, "That username or email is already registered.");
    }
    throw error;
  } finally {
    client.release();
  }
}

export async function login(username: string, password: string) {
  const identifier = username.trim();
  const result = await pool.query<UserRow>(
    `SELECT id, username, role, password_hash, is_active
     FROM users
     WHERE username = $1 OR LOWER(email) = LOWER($1)
     ORDER BY CASE WHEN username = $1 THEN 0 ELSE 1 END
     LIMIT 1`,
    [identifier],
  );
  const user = result.rows[0];
  const passwordMatches = user ? await bcrypt.compare(password, user.password_hash) : false;
  if (!user || !passwordMatches) {
    throw new AppError(401, "Invalid username or password");
  }
  if (!user.is_active) {
    throw new AppError(403, "Account is inactive");
  }

  const token = jwt.sign({ sub: user.id }, config.JWT_SECRET, { expiresIn: "12h" });
  return {
    user: {
      id: user.id,
      username: user.username,
      role: user.role,
    },
    token,
  };
}

export async function changePassword(userId: string, currentPassword: string, newPassword: string) {
  const result = await pool.query<{ id: string; password_hash: string }>(
    "SELECT id, password_hash FROM users WHERE id = $1",
    [userId],
  );
  const user = result.rows[0];
  if (!user) {
    throw new AppError(404, "Account not found.");
  }
  const matches = await bcrypt.compare(currentPassword, user.password_hash);
  if (!matches) {
    throw new AppError(400, "Current password is incorrect.");
  }
  if (newPassword.length < 4) {
    throw new AppError(400, "Password must be at least 4 characters.");
  }
  if (currentPassword === newPassword) {
    throw new AppError(400, "New password must be different from the current password.");
  }
  const passwordHash = await hashPassword(newPassword);
  await pool.query("UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1", [
    userId,
    passwordHash,
  ]);
  // Issue a fresh token so the session continues after the password change.
  const token = jwt.sign({ sub: userId }, config.JWT_SECRET, { expiresIn: "12h" });
  return { ok: true, token };
}
