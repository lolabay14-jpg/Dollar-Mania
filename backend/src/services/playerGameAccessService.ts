import type { PoolClient } from "pg";
import { pool, withTransaction } from "../db";
import { AppError } from "../errors";
import { getUser, type PlayerSummary } from "./userService";

type GameRow = {
  id: string;
  name: string;
  slug: string;
  description: string;
  difficulty: string;
  category: string;
  is_active: boolean;
};

export type PlayerGameAccessItem = {
  gameId: string;
  slug: string;
  name: string;
  description: string;
  category: string;
  difficulty: string;
  globallyActive: boolean;
  enabled: boolean;
  source: "default" | "explicit";
};

export type PlayerGameAccessSummary = {
  player: {
    id: string;
    username: string;
    email: string;
    status: string;
    credits: number;
  };
  totalGames: number;
  enabledCount: number;
  disabledCount: number;
  games: PlayerGameAccessItem[];
};

export async function findPlayerForAccess(query: string): Promise<PlayerSummary> {
  const needle = query.trim();
  if (!needle) {
    throw new AppError(400, "Enter a username or email.");
  }
  const exact = await pool.query<{ id: string }>(
    `SELECT id
     FROM users
     WHERE role = 'PLAYER'
       AND (LOWER(email) = LOWER($1) OR LOWER(username) = LOWER($1))
     LIMIT 1`,
    [needle],
  );
  if (exact.rows[0]) {
    return getUser(exact.rows[0].id);
  }
  const partial = await pool.query<{ id: string }>(
    `SELECT id
     FROM users
     WHERE role = 'PLAYER'
       AND (LOWER(email) LIKE LOWER($1) OR LOWER(username) LIKE LOWER($1))
     ORDER BY username ASC
     LIMIT 1`,
    [`%${needle}%`],
  );
  const row = partial.rows[0];
  if (!row) {
    throw new AppError(404, "Player not found.");
  }
  return getUser(row.id);
}

export async function listPlayerGameAccess(playerId: string): Promise<PlayerGameAccessSummary> {
  const player = await requirePlayer(playerId);
  const games = await listCatalogGames();
  const controls = await pool.query<{ game_id: string; enabled: boolean }>(
    `SELECT game_id, enabled
     FROM player_game_controls
     WHERE player_id = $1`,
    [playerId],
  );
  const byGame = new Map(controls.rows.map((row) => [row.game_id, row.enabled]));
  const items = games.map((game) => {
    const explicit = byGame.has(game.id);
    const enabled = explicit ? Boolean(byGame.get(game.id)) : true;
    return {
      gameId: game.id,
      slug: game.slug,
      name: game.name,
      description: game.description,
      category: game.category,
      difficulty: game.difficulty,
      globallyActive: game.is_active,
      enabled,
      source: explicit ? ("explicit" as const) : ("default" as const),
    };
  });
  const enabledCount = items.filter((item) => item.enabled).length;
  return {
    player: {
      id: player.id,
      username: player.username,
      email: player.email,
      status: player.isActive ? "Active" : "Inactive",
      credits: player.balance,
    },
    totalGames: items.length,
    enabledCount,
    disabledCount: items.length - enabledCount,
    games: items,
  };
}

export async function setPlayerGameAccess(
  actorId: string,
  playerId: string,
  gameKey: string,
  enabled: boolean,
) {
  return withTransaction(async (client) => {
    const player = await requirePlayer(playerId);
    const game = await findGame(client, gameKey);
    const previous = await readControl(client, playerId, game.id);
    const previousEnabled = previous === null ? true : previous;
    if (enabled) {
      await client.query("DELETE FROM player_game_controls WHERE player_id = $1 AND game_id = $2", [
        playerId,
        game.id,
      ]);
    } else {
      await client.query(
        `INSERT INTO player_game_controls (player_id, game_id, enabled, updated_by)
         VALUES ($1, $2, false, $3)
         ON CONFLICT (player_id, game_id) DO UPDATE
         SET enabled = false,
             updated_at = now(),
             updated_by = EXCLUDED.updated_by`,
        [playerId, game.id, actorId],
      );
    }
    if (previousEnabled !== enabled) {
      await writeActivity(
        client,
        actorId,
        playerId,
        enabled ? "ENABLE_PLAYER_GAME" : "DISABLE_PLAYER_GAME",
        `${enabled ? "Enabled" : "Disabled"} ${game.name} for ${player.username} (was ${previousEnabled ? "enabled" : "disabled"} → now ${enabled ? "enabled" : "disabled"}; game ${game.id})`,
      );
    }
    return listPlayerGameAccess(playerId);
  });
}

export async function setAllPlayerGameAccess(actorId: string, playerId: string, enabled: boolean) {
  return withTransaction(async (client) => {
    const player = await requirePlayer(playerId);
    const games = await listCatalogGames(client);
    if (enabled) {
      await client.query("DELETE FROM player_game_controls WHERE player_id = $1", [playerId]);
    } else {
      for (const game of games) {
        await client.query(
          `INSERT INTO player_game_controls (player_id, game_id, enabled, updated_by)
           VALUES ($1, $2, false, $3)
           ON CONFLICT (player_id, game_id) DO UPDATE
           SET enabled = false,
               updated_at = now(),
               updated_by = EXCLUDED.updated_by`,
          [playerId, game.id, actorId],
        );
      }
    }
    await writeActivity(
      client,
      actorId,
      playerId,
      enabled ? "ENABLE_ALL_PLAYER_GAMES" : "DISABLE_ALL_PLAYER_GAMES",
      `${enabled ? "Enabled" : "Disabled"} all games for ${player.username}`,
    );
    return listPlayerGameAccess(playerId);
  });
}

export async function getDisabledGameIds(playerId: string): Promise<Set<string>> {
  const result = await pool.query<{ game_id: string }>(
    `SELECT game_id
     FROM player_game_controls
     WHERE player_id = $1 AND enabled = false`,
    [playerId],
  );
  return new Set(result.rows.map((row) => row.game_id));
}

export async function assertPlayerCanPlayGame(
  client: PoolClient,
  playerId: string,
  gameId: string,
) {
  const result = await client.query<{ enabled: boolean }>(
    `SELECT enabled
     FROM player_game_controls
     WHERE player_id = $1 AND game_id = $2`,
    [playerId, gameId],
  );
  const row = result.rows[0];
  if (row && row.enabled === false) {
    throw new AppError(403, "This game is currently unavailable for your account.");
  }
}

async function requirePlayer(playerId: string) {
  const user = await getUser(playerId);
  if (user.role !== "PLAYER") {
    throw new AppError(400, "Game access can only be configured for player accounts.");
  }
  return user;
}

async function listCatalogGames(db: PoolClient | typeof pool = pool): Promise<GameRow[]> {
  const result = await db.query<GameRow>(
    `SELECT id, name, slug, description, difficulty, category, is_active
     FROM slot_games
     WHERE is_active = true
     ORDER BY name ASC`,
  );
  return result.rows;
}

async function findGame(client: PoolClient, gameKey: string): Promise<GameRow> {
  const result = await client.query<GameRow>(
    `SELECT id, name, slug, description, difficulty, category, is_active
     FROM slot_games
     WHERE (id::text = $1 OR slug = $1) AND is_active = true`,
    [gameKey],
  );
  const game = result.rows[0];
  if (!game) {
    throw new AppError(404, "That game is not available.");
  }
  return game;
}

async function readControl(client: PoolClient, playerId: string, gameId: string) {
  const result = await client.query<{ enabled: boolean }>(
    `SELECT enabled FROM player_game_controls WHERE player_id = $1 AND game_id = $2`,
    [playerId, gameId],
  );
  if (!result.rows[0]) {
    return null;
  }
  return Boolean(result.rows[0].enabled);
}

async function writeActivity(
  client: PoolClient,
  adminId: string,
  userId: string,
  action: string,
  description: string,
) {
  await client.query(
    `INSERT INTO admin_activity (admin_user_id, target_user_id, action, description)
     VALUES ($1, $2, $3, $4)`,
    [adminId, userId, action, description],
  );
}
