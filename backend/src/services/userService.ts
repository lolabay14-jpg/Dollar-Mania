import type { PoolClient } from "pg";
import { config } from "../config";
import { pool, withTransaction } from "../db";
import { AppError } from "../errors";
import { hashPassword } from "./authService";

export type PlayerSummary = {
  id: string;
  username: string;
  email: string;
  role: "ADMIN" | "PLAYER";
  isActive: boolean;
  displayName: string | null;
  level: number | null;
  experience: number | null;
  balance: number;
  createdAt: string;
};

export async function listPlayers(): Promise<PlayerSummary[]> {
  const result = await pool.query(
    `SELECT u.id, u.username, u.email, u.role, u.is_active, u.created_at,
            p.display_name, p.level, p.experience, COALESCE(w.balance, 0) AS balance
     FROM users u
     LEFT JOIN player_profiles p ON p.user_id = u.id
     LEFT JOIN wallets w ON w.user_id = u.id
     WHERE u.role = 'PLAYER'
     ORDER BY u.created_at ASC`,
  );
  return result.rows.map(mapPlayer);
}

export async function findUserByEmail(email: string): Promise<PlayerSummary> {
  const result = await pool.query(
    `SELECT u.id, u.username, u.email, u.role, u.is_active, u.created_at,
            p.display_name, p.level, p.experience, COALESCE(w.balance, 0) AS balance
     FROM users u
     LEFT JOIN player_profiles p ON p.user_id = u.id
     LEFT JOIN wallets w ON w.user_id = u.id
     WHERE LOWER(u.email) = LOWER($1)`,
    [email],
  );
  const row = result.rows[0];
  if (!row) {
    throw new AppError(404, "No user found with that email.");
  }
  return mapPlayer(row);
}

export async function getUser(userId: string): Promise<PlayerSummary> {
  const result = await pool.query(
    `SELECT u.id, u.username, u.email, u.role, u.is_active, u.created_at,
            p.display_name, p.level, p.experience, COALESCE(w.balance, 0) AS balance
     FROM users u
     LEFT JOIN player_profiles p ON p.user_id = u.id
     LEFT JOIN wallets w ON w.user_id = u.id
     WHERE u.id = $1`,
    [userId],
  );
  const row = result.rows[0];
  if (!row) {
    throw new AppError(404, "That user could not be found.");
  }
  return mapPlayer(row);
}

export async function createPlayer(input: {
  username: string;
  email: string;
  password: string;
  displayName: string;
  startingCredits: number;
  adminId: string;
}) {
  const existing = await pool.query("SELECT id FROM users WHERE username = $1 OR email = $2", [
    input.username,
    input.email,
  ]);
  if (existing.rowCount) {
    throw new AppError(409, "That username or email is already registered.");
  }

  const passwordHash = await hashPassword(input.password);
  const createdId = await withTransaction(async (client) => {
    const user = await client.query<{ id: string }>(
      `INSERT INTO users (username, email, password_hash, role)
       VALUES ($1, $2, $3, 'PLAYER')
       RETURNING id`,
      [input.username, input.email, passwordHash],
    );
    const userId = user.rows[0].id;
    await client.query(
      `INSERT INTO player_profiles (user_id, display_name, level, experience)
       VALUES ($1, $2, 1, 0)`,
      [userId, input.displayName],
    );
    await client.query("INSERT INTO wallets (user_id, balance) VALUES ($1, 0)", [userId]);
    if (input.startingCredits > 0) {
      await applyWalletDelta(client, {
        userId,
        adminId: input.adminId,
        delta: input.startingCredits,
        transactionType: "BONUS",
        action: "CREATE_PLAYER",
        description: "Starting credits",
      });
    } else {
      await client.query(
        `INSERT INTO admin_activity (admin_user_id, target_user_id, action, amount, description)
         VALUES ($1, $2, 'CREATE_PLAYER', 0, $3)`,
        [input.adminId, userId, `Created player ${input.username}`],
      );
    }
    return userId;
  });
  return getUser(createdId);
}

export async function updatePlayer(
  userId: string,
  adminId: string,
  input: { isActive?: boolean; displayName?: string },
) {
  const current = await getUser(userId);
  if (current.role !== "PLAYER") {
    throw new AppError(400, "Only player accounts can be edited here.");
  }

  await withTransaction(async (client) => {
    if (input.isActive !== undefined) {
      await client.query("UPDATE users SET is_active = $2, updated_at = now() WHERE id = $1", [
        userId,
        input.isActive,
      ]);
      await client.query(
        `INSERT INTO admin_activity (admin_user_id, target_user_id, action, description)
         VALUES ($1, $2, $3, $4)`,
        [
          adminId,
          userId,
          input.isActive ? "ACTIVATE_PLAYER" : "DEACTIVATE_PLAYER",
          input.isActive ? "Activated player" : "Deactivated player",
        ],
      );
    }
    if (input.displayName !== undefined) {
      await client.query(
        "UPDATE player_profiles SET display_name = $2, updated_at = now() WHERE user_id = $1",
        [userId, input.displayName],
      );
    }
  });
  return getUser(userId);
}

export async function adjustCredits(input: {
  userId: string;
  adminId: string;
  amount: number;
  action: "add" | "remove";
}) {
  const delta = input.action === "add" ? input.amount : -input.amount;
  const transactionType = input.action === "add" ? "ADMIN_ADD" : "ADMIN_REMOVE";
  const description = input.action === "add" ? "Admin added credits" : "Admin removed credits";

  const balance = await withTransaction(async (client) => {
    return applyWalletDelta(client, {
      userId: input.userId,
      adminId: input.adminId,
      delta,
      transactionType,
      action: transactionType,
      description,
    });
  });
  return { balance };
}

export async function listTransactions(limit = 50) {
  const result = await pool.query(
    `SELECT t.id, t.user_id, u.username, p.display_name, t.amount, t.balance_after,
            t.transaction_type, t.description, t.created_at
     FROM credit_transactions t
     JOIN users u ON u.id = t.user_id
     LEFT JOIN player_profiles p ON p.user_id = u.id
     ORDER BY t.created_at DESC
     LIMIT $1`,
    [limit],
  );
  return result.rows.map(mapTransaction);
}

export async function listActivity(limit = 50) {
  const result = await pool.query(
    `SELECT a.id, a.action, a.amount, a.description, a.created_at,
            admin_user.username AS admin_username,
            target_user.username AS target_username,
            target_profile.display_name AS target_display_name
     FROM admin_activity a
     JOIN users admin_user ON admin_user.id = a.admin_user_id
     JOIN users target_user ON target_user.id = a.target_user_id
     LEFT JOIN player_profiles target_profile ON target_profile.user_id = target_user.id
     ORDER BY a.created_at DESC
     LIMIT $1`,
    [limit],
  );
  return result.rows.map((row) => ({
    id: row.id,
    action: row.action,
    amount: row.amount === null ? null : Number(row.amount),
    description: row.description,
    adminUsername: row.admin_username,
    targetUsername: row.target_username,
    targetDisplayName: row.target_display_name,
    createdAt: row.created_at,
  }));
}

export async function getOwnProfile(userId: string) {
  const user = await getUser(userId);
  if (user.role !== "PLAYER") {
    throw new AppError(404, "Player profile not found.");
  }
  const stats = await pool.query<{ spins: string; wins: string; losses: string }>(
    `SELECT COUNT(*) AS spins,
            COUNT(*) FILTER (WHERE win_amount > 0) AS wins,
            COUNT(*) FILTER (WHERE win_amount = 0) AS losses
     FROM slot_spins
     WHERE user_id = $1`,
    [userId],
  );
  const row = stats.rows[0];
  return {
    id: user.id,
    username: user.username,
    displayName: user.displayName,
    avatar: null,
    level: user.level ?? 1,
    experience: user.experience ?? 0,
    credits: user.balance,
    spins: Number(row?.spins ?? 0),
    wins: Number(row?.wins ?? 0),
    losses: Number(row?.losses ?? 0),
  };
}

export async function getOwnWallet(userId: string) {
  const result = await pool.query<{ balance: number }>(
    "SELECT balance FROM wallets WHERE user_id = $1",
    [userId],
  );
  const row = result.rows[0];
  if (!row) {
    throw new AppError(404, "Wallet not found.");
  }
  return { balance: Number(row.balance) };
}

export async function getOwnTransactions(userId: string) {
  const result = await pool.query(
    `SELECT t.id, t.user_id, u.username, p.display_name, t.amount, t.balance_after,
            t.transaction_type, t.description, t.created_at
     FROM credit_transactions t
     JOIN users u ON u.id = t.user_id
     LEFT JOIN player_profiles p ON p.user_id = u.id
     WHERE t.user_id = $1
     ORDER BY t.created_at DESC
     LIMIT 50`,
    [userId],
  );
  return result.rows.map(mapTransaction);
}

export async function getOwnSpins(userId: string) {
  const result = await pool.query(
    `SELECT s.id, s.bet_amount, s.win_amount, s.multiplier, s.result, s.created_at,
            g.name AS game_name, g.slug AS game_slug
     FROM slot_spins s
     JOIN slot_games g ON g.id = s.slot_game_id
     WHERE s.user_id = $1
     ORDER BY s.created_at DESC
     LIMIT 30`,
    [userId],
  );
  return result.rows.map((row) => ({
    id: row.id,
    gameName: row.game_name,
    gameSlug: row.game_slug,
    betAmount: Number(row.bet_amount),
    winAmount: Number(row.win_amount),
    multiplier: Number(row.multiplier),
    result: row.result,
    createdAt: row.created_at,
  }));
}

async function applyWalletDelta(
  client: PoolClient,
  input: {
    userId: string;
    adminId: string | null;
    delta: number;
    transactionType: "ADMIN_ADD" | "ADMIN_REMOVE" | "BONUS" | "REFUND";
    action: string;
    description: string;
  },
) {
  const locked = await client.query<{ balance: number }>(
    "SELECT balance FROM wallets WHERE user_id = $1 FOR UPDATE",
    [input.userId],
  );
  const wallet = locked.rows[0];
  if (!wallet) {
    throw new AppError(404, "That player does not have a wallet.");
  }
  const nextBalance = Number(wallet.balance) + input.delta;
  if (nextBalance < 0) {
    throw new AppError(400, "That player does not have enough credits.");
  }
  await client.query("UPDATE wallets SET balance = $2, updated_at = now() WHERE user_id = $1", [
    input.userId,
    nextBalance,
  ]);
  await client.query(
    `INSERT INTO credit_transactions
       (user_id, amount, balance_after, transaction_type, description, created_by)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [input.userId, input.delta, nextBalance, input.transactionType, input.description, input.adminId],
  );
  if (input.adminId) {
    await client.query(
      `INSERT INTO admin_activity (admin_user_id, target_user_id, action, amount, description)
       VALUES ($1, $2, $3, $4, $5)`,
      [input.adminId, input.userId, input.action, input.delta, input.description],
    );
  }
  return nextBalance;
}

function mapPlayer(row: {
  id: string;
  username: string;
  email: string;
  role: "ADMIN" | "PLAYER";
  is_active: boolean;
  display_name: string | null;
  level: number | null;
  experience: number | null;
  balance: number;
  created_at: Date;
}): PlayerSummary {
  return {
    id: row.id,
    username: row.username,
    email: row.email,
    role: row.role,
    isActive: row.is_active,
    displayName: row.display_name,
    level: row.level === null ? null : Number(row.level),
    experience: row.experience === null ? null : Number(row.experience),
    balance: Number(row.balance),
    createdAt: row.created_at.toISOString(),
  };
}

function mapTransaction(row: {
  id: string;
  user_id: string;
  username: string;
  display_name: string | null;
  amount: number;
  balance_after: number;
  transaction_type: string;
  description: string;
  created_at: Date;
}) {
  return {
    id: row.id,
    userId: row.user_id,
    username: row.username,
    displayName: row.display_name,
    amount: Number(row.amount),
    balanceAfter: Number(row.balance_after),
    transactionType: row.transaction_type,
    description: row.description,
    createdAt: row.created_at.toISOString(),
  };
}

export const startingCredits = config.STARTING_CREDITS;
