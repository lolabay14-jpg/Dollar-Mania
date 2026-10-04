import type { PoolClient } from "pg";
import { config } from "../config";
import { pool, withTransaction } from "../db";
import { AppError } from "../errors";
import { hashPassword } from "./authService";
import { applyCreditMove, moveCredits } from "./creditTransfer";
import type { AppRole } from "../middleware/authenticate";

export type PlayerGameMode = "EASY" | "MEDIUM" | "HARD";

export type PlayerSummary = {
  id: string;
  username: string;
  email: string;
  role: AppRole;
  isActive: boolean;
  displayName: string | null;
  level: number | null;
  experience: number | null;
  balance: number;
  gameMode: PlayerGameMode;
  createdAt: string;
};

export async function listPlayers(): Promise<PlayerSummary[]> {
  const result = await pool.query(
    `SELECT u.id, u.username, u.email, u.role, u.is_active, u.game_mode, u.created_at,
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
    `SELECT u.id, u.username, u.email, u.role, u.is_active, u.game_mode, u.created_at,
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
    `SELECT u.id, u.username, u.email, u.role, u.is_active, u.game_mode, u.created_at,
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
  const existing = await pool.query<{ username: string; email: string }>(
    "SELECT username, email FROM users WHERE username = $1 OR LOWER(email) = LOWER($2)",
    [input.username, input.email],
  );
  if (existing.rows.some((row) => row.username === input.username)) {
    throw new AppError(409, "That username is already registered.");
  }
  if (existing.rows.some((row) => row.email.toLowerCase() === input.email.toLowerCase())) {
    throw new AppError(409, "That email is already registered.");
  }

  const passwordHash = await hashPassword(input.password);
  let createdId: string;
  try {
    createdId = await withTransaction(async (client) => {
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
      await applyCreditMove(client, {
        actorId: input.adminId,
        targetId: userId,
        amount: input.startingCredits,
        action: "transfer",
        note: "Starting credits",
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
  } catch (error) {
    const unique = uniqueAccountMessage(error);
    if (unique) {
      throw new AppError(409, unique);
    }
    throw error;
  }
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

export async function createAdmin(input: {
  username: string;
  email: string;
  password: string;
  displayName: string;
  adminId: string;
}) {
  const actor = await getUser(input.adminId);
  if (actor.role !== "SUPER_ADMIN") {
    throw new AppError(403, "Unauthorized action.");
  }
  const existing = await pool.query<{ username: string; email: string }>(
    "SELECT username, email FROM users WHERE username = $1 OR LOWER(email) = LOWER($2)",
    [input.username, input.email],
  );
  if (existing.rows.some((row) => row.username === input.username)) {
    throw new AppError(409, "That username is already registered.");
  }
  if (existing.rows.some((row) => row.email.toLowerCase() === input.email.toLowerCase())) {
    throw new AppError(409, "That email is already registered.");
  }
  const passwordHash = await hashPassword(input.password);
  let createdId: string;
  try {
    createdId = await withTransaction(async (client) => {
      const user = await client.query<{ id: string }>(
        `INSERT INTO users (username, email, password_hash, role)
         VALUES ($1, $2, $3, 'ADMIN')
         RETURNING id`,
        [input.username, input.email, passwordHash],
      );
      const userId = user.rows[0].id;
      await client.query("INSERT INTO wallets (user_id, balance) VALUES ($1, 0)", [userId]);
      await client.query(
        `INSERT INTO admin_activity (admin_user_id, target_user_id, action, amount)
         VALUES ($1, $2, 'CREATE_ADMIN', 0)`,
        [input.adminId, userId],
      );
      return userId;
    });
  } catch (error) {
    const unique = uniqueAccountMessage(error);
    if (unique) {
      throw new AppError(409, unique);
    }
    throw error;
  }
  return getUser(createdId);
}

export async function setStaffActive(actorId: string, userId: string, isActive: boolean) {
  const actor = await getUser(actorId);
  if (actor.role !== "SUPER_ADMIN") {
    throw new AppError(403, "Unauthorized action.");
  }
  if (actorId === userId) {
    throw new AppError(400, "You cannot change your own access.");
  }
  const current = await getUser(userId);
  if (current.role !== "ADMIN") {
    throw new AppError(400, "Only admin accounts can be changed here.");
  }
  await withTransaction(async (client) => {
    await client.query("UPDATE users SET is_active = $2, updated_at = now() WHERE id = $1 AND role = 'ADMIN'", [
      userId,
      isActive,
    ]);
    await client.query(
      `INSERT INTO admin_activity (admin_user_id, target_user_id, action)
       VALUES ($1, $2, $3)`,
      [actorId, userId, isActive ? "ACTIVATE_ADMIN" : "DEACTIVATE_ADMIN"],
    );
  });
  return getUser(userId);
}

export async function setPlayerGameMode(userId: string, adminId: string, gameMode: PlayerGameMode) {
  const current = await getUser(userId);
  if (current.role !== "PLAYER") {
    throw new AppError(400, "Only player accounts can be assigned a game mode.");
  }
  await withTransaction(async (client) => {
    await client.query("UPDATE users SET game_mode = $2, updated_at = now() WHERE id = $1", [
      userId,
      gameMode,
    ]);
    await client.query(
      `INSERT INTO admin_activity (admin_user_id, target_user_id, action, description)
       VALUES ($1, $2, 'SET_GAME_MODE', $3)`,
      [adminId, userId, `Set game mode to ${gameMode} for ${current.username}`],
    );
  });
  return getUser(userId);
}

export async function adjustCredits(input: {
  userId: string;
  adminId: string;
  amount: number;
  action: "add" | "remove";
  note?: string;
  requestId?: string;
}) {
  const moved = await moveCredits({
    actorId: input.adminId,
    targetId: input.userId,
    amount: input.amount,
    action: input.action === "add" ? "transfer" : "reclaim",
    note: input.note,
    requestId: input.requestId,
  });
  return moved;
}

export async function getAdminOverview(userId: string) {
  const counts = await pool.query<{
    total_players: number;
    active_players: number;
    total_admins: number;
    active_admins: number;
    active_games: number;
    player_credits: number;
    total_credits: number;
    allocated_credits: number;
    total_games: number;
    total_spins: number;
    total_sessions: number;
    my_balance: number;
  }>(
    `SELECT
       (SELECT COUNT(*)::int FROM users WHERE role = 'PLAYER') AS total_players,
       (SELECT COUNT(*)::int FROM users WHERE role = 'PLAYER' AND is_active = true) AS active_players,
       (SELECT COUNT(*)::int FROM users WHERE role = 'ADMIN') AS total_admins,
       (SELECT COUNT(*)::int FROM users WHERE role = 'ADMIN' AND is_active = true) AS active_admins,
       (SELECT COUNT(*)::int FROM slot_games WHERE is_active = true) AS active_games,
       (SELECT COALESCE(SUM(w.balance), 0) FROM wallets w JOIN users u ON u.id = w.user_id AND u.role = 'PLAYER') AS player_credits,
       (SELECT COALESCE(SUM(w.balance), 0) FROM wallets w JOIN users u ON u.id = w.user_id AND u.role IN ('ADMIN', 'PLAYER')) AS total_credits,
       (SELECT COALESCE(SUM(w.balance), 0) FROM wallets w JOIN users u ON u.id = w.user_id AND u.role = 'ADMIN') AS allocated_credits,
       (SELECT COUNT(*)::int FROM slot_games) AS total_games,
       (SELECT COUNT(*)::int FROM slot_spins) AS total_spins,
       (SELECT COUNT(*)::int FROM game_sessions) AS total_sessions,
       (SELECT COALESCE(balance, 0) FROM wallets WHERE user_id = $1) AS my_balance`,
    [userId],
  );
  const row = counts.rows[0];
  const [recentTransactions, recentActivity, recentPlays] = await Promise.all([
    listTransactions(8),
    listActivity(8),
    listRecentPlays(8),
  ]);
  return {
    totalPlayers: Number(row?.total_players ?? 0),
    activePlayers: Number(row?.active_players ?? 0),
    totalAdmins: Number(row?.total_admins ?? 0),
    activeAdmins: Number(row?.active_admins ?? 0),
    activeGames: Number(row?.active_games ?? 0),
    totalCredits: Number(row?.total_credits ?? 0),
    playerCredits: Number(row?.player_credits ?? 0),
    allocatedCredits: Number(row?.allocated_credits ?? 0),
    myBalance: Number(row?.my_balance ?? 0),
    totalGames: Number(row?.total_games ?? 0),
    totalSpins: Number(row?.total_spins ?? 0),
    totalSessions: Number(row?.total_sessions ?? 0),
    recentTransactions,
    recentActivity,
    recentPlays,
  };
}

export async function listStaff(): Promise<PlayerSummary[]> {
  const result = await pool.query(
    `SELECT u.id, u.username, u.email, u.role, u.is_active, u.game_mode, u.created_at,
            p.display_name, p.level, p.experience, COALESCE(w.balance, 0) AS balance
     FROM users u
     LEFT JOIN player_profiles p ON p.user_id = u.id
     LEFT JOIN wallets w ON w.user_id = u.id
     WHERE u.role = 'ADMIN'
     ORDER BY u.created_at ASC`,
  );
  return result.rows.map(mapPlayer);
}

export async function ensureSuperAdmin() {
  if (!config.SUPER_ADMIN_PASSWORD) {
    return { created: false };
  }
  const existing = await pool.query<{ id: string }>("SELECT id FROM users WHERE username = $1", [
    config.SUPER_ADMIN_USERNAME,
  ]);
  if (existing.rowCount) {
    return { created: false };
  }
  const passwordHash = await hashPassword(config.SUPER_ADMIN_PASSWORD);
  await withTransaction(async (client) => {
    const user = await client.query<{ id: string }>(
      `INSERT INTO users (username, email, password_hash, role)
       VALUES ($1, $2, $3, 'SUPER_ADMIN')
       RETURNING id`,
      [config.SUPER_ADMIN_USERNAME, `${config.SUPER_ADMIN_USERNAME}@dollarmania.local`, passwordHash],
    );
    const userId = user.rows[0].id;
    await client.query("INSERT INTO wallets (user_id, balance) VALUES ($1, $2)", [
      userId,
      config.SUPER_ADMIN_CREDITS,
    ]);
    if (config.SUPER_ADMIN_CREDITS > 0) {
      await client.query(
        `INSERT INTO credit_transactions
           (user_id, amount, balance_after, transaction_type, description, created_by)
         VALUES ($1, $2, $2, 'BONUS', 'Opening treasury', $1)`,
        [userId, config.SUPER_ADMIN_CREDITS],
      );
    }
  });
  return { created: true };
}

export async function listRecentPlays(limit = 40) {
  const result = await pool.query(
    `SELECT s.id, s.bet_amount, s.win_amount, s.created_at,
            u.username, g.name AS game_name
     FROM slot_spins s
     JOIN users u ON u.id = s.user_id
     JOIN slot_games g ON g.id = s.slot_game_id
     ORDER BY s.created_at DESC
     LIMIT $1`,
    [limit],
  );
  return result.rows.map((row) => ({
    id: row.id,
    username: row.username,
    gameName: row.game_name,
    betAmount: Number(row.bet_amount),
    winAmount: Number(row.win_amount),
    createdAt: row.created_at,
  }));
}

export async function getAccountLedger(userId: string) {
  const user = await getUser(userId);
  if (user.role === "SUPER_ADMIN") {
    throw new AppError(403, "You do not have access to this resource.");
  }
  return { user, transactions: await getOwnTransactions(userId) };
}

export async function getPlayerHistory(userId: string) {
  const user = await getUser(userId);
  if (user.role !== "PLAYER") {
    throw new AppError(400, "Only player accounts can be opened here.");
  }
  const [transactions, spins, activity] = await Promise.all([
    getOwnTransactions(userId),
    getOwnSpins(userId),
    listActivityForPlayer(userId),
  ]);
  return { user, transactions, spins, activity };
}

async function listActivityForPlayer(userId: string, limit = 30) {
  const result = await pool.query(
    `SELECT a.id, a.action, a.amount, a.description, a.created_at,
            admin_user.username AS admin_username,
            target_user.username AS target_username,
            target_profile.display_name AS target_display_name
     FROM admin_activity a
     JOIN users admin_user ON admin_user.id = a.admin_user_id
     JOIN users target_user ON target_user.id = a.target_user_id
     LEFT JOIN player_profiles target_profile ON target_profile.user_id = target_user.id
     WHERE a.target_user_id = $1
     ORDER BY a.created_at DESC
     LIMIT $2`,
    [userId, limit],
  );
  return result.rows.map(mapActivity);
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
     LEFT JOIN users target_user ON target_user.id = a.target_user_id
     LEFT JOIN player_profiles target_profile ON target_profile.user_id = target_user.id
     ORDER BY a.created_at DESC
     LIMIT $1`,
    [limit],
  );
  return result.rows.map(mapActivity);
}

function mapActivity(row: {
  id: string;
  action: string;
  amount: number | null;
  description: string | null;
  admin_username: string;
  target_username: string | null;
  target_display_name: string | null;
  created_at: Date;
}) {
  return {
    id: row.id,
    action: row.action,
    amount: row.amount === null ? null : Number(row.amount),
    description: row.description,
    adminUsername: row.admin_username,
    targetUsername: row.target_username,
    targetDisplayName: row.target_display_name,
    createdAt: row.created_at,
  };
}

function uniqueAccountMessage(error: unknown): string | null {
  if (typeof error !== "object" || !error || !("code" in error) || String(error.code) !== "23505") {
    return null;
  }
  const constraint = "constraint" in error ? String(error.constraint) : "";
  if (constraint.includes("email")) {
    return "That email is already registered.";
  }
  if (constraint.includes("username")) {
    return "That username is already registered.";
  }
  return "That username or email is already registered.";
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
  role: AppRole;
  is_active: boolean;
  display_name: string | null;
  level: number | null;
  experience: number | null;
  balance: number;
  game_mode: string | null;
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
    gameMode: asPlayerGameMode(row.game_mode),
    createdAt: row.created_at.toISOString(),
  };
}

function asPlayerGameMode(value: string | null | undefined): PlayerGameMode {
  const mode = String(value ?? "MEDIUM").toUpperCase();
  if (mode === "EASY" || mode === "HARD") {
    return mode;
  }
  return "MEDIUM";
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
