import type { PoolClient } from "pg";
import { pool, withTransaction } from "../db";
import { AppError } from "../errors";
import { resolveRound } from "./gamePlay";
import { getAssignedTuning } from "./gameProfileService";
import { assertPlayerCanPlayGame, getDisabledGameIds } from "./playerGameAccessService";

export type SlotGame = {
  id: string;
  name: string;
  slug: string;
  description: string;
  difficulty: string;
  category: string;
  minimumBet: number;
  maximumBet: number;
  isActive: boolean;
};

export async function listActiveGames(): Promise<SlotGame[]> {
  const result = await pool.query(
    `SELECT id, name, slug, description, difficulty, category, minimum_bet, maximum_bet, is_active
     FROM slot_games
     WHERE is_active = true
     ORDER BY CASE slug
       WHEN 'lucky-dollar' THEN 1
       WHEN 'golden-fortune' THEN 2
       WHEN 'dollar-rush' THEN 3
       WHEN 'scratch-mania' THEN 4
       WHEN 'lucky-spin' THEN 5
       WHEN 'coin-flip' THEN 6
       WHEN 'treasure-box' THEN 7
       WHEN 'cash-match' THEN 8
       WHEN 'diamond-drop' THEN 9
       WHEN 'bonus-burst' THEN 10
       WHEN 'jackpot-wheel' THEN 11
       WHEN 'higher-card' THEN 12
       WHEN 'fruit-spin' THEN 13
       WHEN 'lucky-wheel' THEN 14
       WHEN 'prize-spinner' THEN 15
       WHEN 'fishing' THEN 16
       WHEN 'dice' THEN 17
       WHEN 'lucky-number' THEN 18
       WHEN 'diamond-spin' THEN 19
       WHEN 'mystery-box' THEN 20
       WHEN 'target-blast' THEN 21
       WHEN 'aeroplane-rush' THEN 22
       WHEN 'bottle-blast' THEN 23
       ELSE 100
     END, name ASC`,
  );
  return result.rows.map(mapGame);
}

export async function listGamesForPlayer(userId: string): Promise<Array<SlotGame & { enabled: boolean }>> {
  const games = await listActiveGames();
  const disabled = await getDisabledGameIds(userId);
  return games.map((game) => ({
    ...game,
    enabled: !disabled.has(game.id),
  }));
}

export async function setGameActive(gameKey: string, isActive: boolean): Promise<SlotGame> {
  const result = await pool.query(
    `UPDATE slot_games
     SET is_active = $2, updated_at = now()
     WHERE id::text = $1 OR slug = $1
     RETURNING id, name, slug, description, difficulty, category, minimum_bet, maximum_bet, is_active`,
    [gameKey, isActive],
  );
  const row = result.rows[0];
  if (!row) {
    throw new AppError(404, "Game not found.");
  }
  return mapGame(row);
}

export async function listGamesForAdmin(): Promise<Array<SlotGame & { spins: number }>> {
  const result = await pool.query(
    `SELECT g.id, g.name, g.slug, g.description, g.difficulty, g.category,
            g.minimum_bet, g.maximum_bet, g.is_active, COUNT(s.id)::int AS spins
     FROM slot_games g
     LEFT JOIN slot_spins s ON s.slot_game_id = g.id
     GROUP BY g.id
     ORDER BY CASE g.slug
       WHEN 'lucky-dollar' THEN 1
       WHEN 'golden-fortune' THEN 2
       WHEN 'dollar-rush' THEN 3
       WHEN 'scratch-mania' THEN 4
       WHEN 'lucky-spin' THEN 5
       WHEN 'coin-flip' THEN 6
       WHEN 'treasure-box' THEN 7
       WHEN 'cash-match' THEN 8
       WHEN 'diamond-drop' THEN 9
       WHEN 'bonus-burst' THEN 10
       WHEN 'jackpot-wheel' THEN 11
       WHEN 'higher-card' THEN 12
       WHEN 'fruit-spin' THEN 13
       WHEN 'lucky-wheel' THEN 14
       WHEN 'prize-spinner' THEN 15
       WHEN 'fishing' THEN 16
       WHEN 'dice' THEN 17
       WHEN 'lucky-number' THEN 18
       WHEN 'diamond-spin' THEN 19
       WHEN 'mystery-box' THEN 20
       WHEN 'target-blast' THEN 21
       WHEN 'aeroplane-rush' THEN 22
       WHEN 'bottle-blast' THEN 23
       ELSE 100
     END, g.name ASC`,
  );
  return result.rows.map((row) => ({
    ...mapGame(row),
    spins: Number(row.spins ?? 0),
  }));
}

type PlayReceipt = {
  playId: string;
  spinId: string;
  result: string[];
  grid: string[][];
  highlights: number[];
  title: string;
  betAmount: number;
  winAmount: number;
  multiplier: number;
  balance: number;
  presentation: Record<string, unknown>;
};

const recentPlays = new Map<string, { at: number; receipt: PlayReceipt }>();
const pendingPlays = new Map<string, Promise<PlayReceipt>>();

export async function spin(
  userId: string,
  gameId: string,
  betAmount: number,
  choice?: unknown,
  requestId?: string,
) {
  const key = requestKey(userId, requestId);
  if (key) {
    const saved = recentPlays.get(key);
    if (saved && Date.now() - saved.at < 90_000) {
      return saved.receipt;
    }
    const pending = pendingPlays.get(key);
    if (pending) {
      return pending;
    }
  }

  const job = completeSpin(userId, gameId, betAmount, choice);
  if (!key) {
    return job;
  }
  pendingPlays.set(key, job);
  try {
    const receipt = await job;
    recentPlays.set(key, { at: Date.now(), receipt });
    if (recentPlays.size > 300) {
      const oldest = recentPlays.keys().next().value;
      if (oldest) {
        recentPlays.delete(oldest);
      }
    }
    return receipt;
  } finally {
    pendingPlays.delete(key);
  }
}

async function completeSpin(userId: string, gameId: string, betAmount: number, choice?: unknown): Promise<PlayReceipt> {
  return withTransaction(async (client) => {
    const gameResult = await client.query(
      `SELECT id, name, slug, description, difficulty, category, minimum_bet, maximum_bet, is_active
       FROM slot_games
       WHERE (id::text = $1 OR slug = $1) AND is_active = true`,
      [gameId],
    );
    const gameRow = gameResult.rows[0];
    if (!gameRow) {
      throw new AppError(404, "That game is not available.");
    }
    const game = mapGame(gameRow);
    await assertPlayerCanPlayGame(client, userId, game.id);
    if (betAmount < game.minimumBet) {
      throw new AppError(400, "Bet is below the minimum.");
    }
    if (betAmount > game.maximumBet) {
      throw new AppError(400, "Bet is above the maximum.");
    }

    const wallet = await client.query<{ balance: number }>(
      "SELECT balance FROM wallets WHERE user_id = $1 FOR UPDATE",
      [userId],
    );
    const current = wallet.rows[0];
    if (!current) {
      throw new AppError(404, "Wallet not found.");
    }
    if (Number(current.balance) < betAmount) {
      throw new AppError(400, "Insufficient credits");
    }

    const tuning = await getAssignedTuning(client, userId, game.id, game.slug, game.difficulty);
    const round = resolveRound(game.slug, choice, tuning.difficulty, tuning.parameters);
    const winAmount = money(betAmount * round.multiplier);
    const afterBet = money(Number(current.balance) - betAmount);
    await client.query("UPDATE wallets SET balance = $2, updated_at = now() WHERE user_id = $1", [
      userId,
      afterBet,
    ]);
    await insertTransaction(client, userId, -betAmount, afterBet, "GAME_BET", `${game.name} bet`);

    const balance = money(afterBet + winAmount);
    if (winAmount > 0) {
      await client.query("UPDATE wallets SET balance = $2, updated_at = now() WHERE user_id = $1", [
        userId,
        balance,
      ]);
      await insertTransaction(client, userId, winAmount, balance, "GAME_WIN", round.title);
    }

    const presentation = round.presentation;
    const result = {
      ...presentation,
      title: round.title,
    };
    const spin = await client.query<{ id: string }>(
      `INSERT INTO slot_spins (user_id, slot_game_id, bet_amount, win_amount, multiplier, result)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb)
       RETURNING id`,
      [userId, game.id, betAmount, winAmount, round.multiplier, JSON.stringify(result)],
    );
    await client.query(
      `INSERT INTO game_sessions
         (user_id, slot_game_id, status, started_at, ended_at, score, credits_used, credits_won)
       VALUES ($1, $2, 'COMPLETED', now(), now(), $3, $4, $5)`,
      [userId, game.id, Math.round(winAmount), betAmount, winAmount],
    );
    await client.query(
      `UPDATE player_profiles
       SET experience = experience + 1,
           level = 1 + ((experience + 1) / 8),
           updated_at = now()
       WHERE user_id = $1`,
      [userId],
    );

    const payline = Array.isArray(presentation.payline) ? presentation.payline.map(String) : [];
    const grid = Array.isArray(presentation.grid) ? (presentation.grid as string[][]) : [];
    const highlights = Array.isArray(presentation.highlights) ? presentation.highlights.map(Number) : [];
    return {
      playId: spin.rows[0].id,
      spinId: spin.rows[0].id,
      result: payline,
      grid,
      highlights,
      title: round.title,
      betAmount,
      winAmount,
      multiplier: round.multiplier,
      balance,
      presentation,
    };
  });
}

function requestKey(userId: string, requestId?: string) {
  if (!requestId) {
    return "";
  }
  if (!/^[A-Za-z0-9_-]{8,80}$/.test(requestId)) {
    throw new AppError(400, "Invalid play request.");
  }
  return `${userId}:${requestId}`;
}

function money(value: number) {
  return Math.round(value * 100) / 100;
}

async function insertTransaction(
  client: PoolClient,
  userId: string,
  amount: number,
  balanceAfter: number,
  transactionType: "GAME_BET" | "GAME_WIN",
  description: string,
) {
  await client.query(
    `INSERT INTO credit_transactions
       (user_id, amount, balance_after, transaction_type, description, created_by)
     VALUES ($1, $2, $3, $4, $5, NULL)`,
    [userId, amount, balanceAfter, transactionType, description],
  );
}

function mapGame(row: {
  id: string;
  name: string;
  slug: string;
  description: string;
  difficulty: string;
  category?: string;
  minimum_bet: number;
  maximum_bet: number;
  is_active: boolean;
}): SlotGame {
  return {
    id: row.id,
    name: row.name,
    slug: row.slug,
    description: row.description,
    difficulty: row.difficulty,
    category: row.category ?? "SLOTS",
    minimumBet: Number(row.minimum_bet),
    maximumBet: Number(row.maximum_bet),
    isActive: row.is_active,
  };
}
