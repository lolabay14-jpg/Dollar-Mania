import type { PoolClient } from "pg";
import { pool, withTransaction } from "../db";
import { AppError } from "../errors";
import {
  defaultParameters,
  parametersForSlug,
  readParameters,
  type ProfileLevel,
  clampParameter,
} from "./gameParameters";
import { findUserByEmail, getUser } from "./userService";

type GameRow = {
  id: string;
  name: string;
  slug: string;
  difficulty: string;
};

type ProfileRow = {
  slot_game_id: string;
  profile: ProfileLevel;
  parameters: Record<string, unknown> | null;
  updated_at: Date;
};

export type PlayerGameProfile = {
  userId: string;
  username: string;
  email: string;
  gameId: string;
  slug: string;
  gameName: string;
  gameDifficulty: string;
  assignedProfile: ProfileLevel;
  parameters: Record<string, number>;
  parameterDefs: ReturnType<typeof parametersForSlug>;
  updatedAt: string | null;
};

export async function getAssignedTuning(
  client: PoolClient,
  userId: string,
  gameId: string,
  slug: string,
  gameDifficulty: string,
) {
  const result = await client.query<ProfileRow>(
    `SELECT slot_game_id, profile, parameters, updated_at
     FROM player_game_profiles
     WHERE user_id = $1 AND slot_game_id = $2`,
    [userId, gameId],
  );
  const row = result.rows[0];
  if (!row || row.profile === "DEFAULT") {
    return { difficulty: gameDifficulty, parameters: {} as Record<string, number> };
  }
  const stored = row.parameters && typeof row.parameters === "object" ? row.parameters : {};
  const parameters: Record<string, number> = {};
  for (const definition of parametersForSlug(slug)) {
    parameters[definition.key] = clampParameter(slug, definition.key, stored[definition.key]);
  }
  return { difficulty: row.profile, parameters };
}

export async function findPlayerForControls(email: string) {
  let user;
  try {
    user = await findUserByEmail(email);
  } catch (error) {
    if (error instanceof AppError && error.status === 404) {
      throw new AppError(404, "Player not found");
    }
    throw error;
  }
  if (user.role !== "PLAYER") {
    throw new AppError(400, "Admin accounts cannot be used for game controls.");
  }
  return {
    id: user.id,
    username: user.username,
    email: user.email,
    credits: user.balance,
    status: user.isActive ? "Active" : "Inactive",
    role: user.role,
  };
}

export async function listPlayerGameProfiles(userId: string): Promise<PlayerGameProfile[]> {
  const user = await requirePlayer(userId);
  const games = await listGames();
  const assigned = await pool.query<ProfileRow>(
    `SELECT slot_game_id, profile, parameters, updated_at
     FROM player_game_profiles
     WHERE user_id = $1`,
    [userId],
  );
  const byGame = new Map(assigned.rows.map((row) => [row.slot_game_id, row]));
  return games.map((game) => present(user, game, byGame.get(game.id)));
}

export async function setPlayerGameProfile(
  adminId: string,
  userId: string,
  gameKey: string,
  profile: ProfileLevel,
  parameters: unknown,
) {
  return withTransaction(async (client) => {
    const user = await requirePlayer(userId);
    const game = await findGame(client, gameKey);
    if (profile === "DEFAULT") {
      await client.query("DELETE FROM player_game_profiles WHERE user_id = $1 AND slot_game_id = $2", [
        userId,
        game.id,
      ]);
      await writeActivity(
        client,
        adminId,
        userId,
        "RESET_GAME_PROFILE",
        `Reset ${game.slug} to DEFAULT for ${user.username}`,
      );
      return present(user, game, undefined);
    }

    const clean = readParameters(game.slug, parameters);
    const saved = await client.query<ProfileRow>(
      `INSERT INTO player_game_profiles (user_id, slot_game_id, profile, parameters, updated_by)
       VALUES ($1, $2, $3, $4::jsonb, $5)
       ON CONFLICT (user_id, slot_game_id) DO UPDATE
       SET profile = EXCLUDED.profile,
           parameters = EXCLUDED.parameters,
           updated_at = now(),
           updated_by = EXCLUDED.updated_by
       RETURNING slot_game_id, profile, parameters, updated_at`,
      [userId, game.id, profile, JSON.stringify(clean), adminId],
    );
    const summary = Object.entries(clean)
      .map(([key, value]) => `${key} ${value}`)
      .join(", ");
    await writeActivity(
      client,
      adminId,
      userId,
      "SET_GAME_PROFILE",
      `Set ${game.slug} to ${profile} for ${user.username}. ${summary}`,
    );
    return present(user, game, saved.rows[0]);
  });
}

async function requirePlayer(userId: string) {
  const user = await getUser(userId);
  if (user.role !== "PLAYER") {
    throw new AppError(400, "Admin accounts cannot be used for game controls.");
  }
  return user;
}

async function listGames(): Promise<GameRow[]> {
  const result = await pool.query<GameRow>(
    `SELECT id, name, slug, difficulty
     FROM slot_games
     WHERE is_active = true
     ORDER BY name ASC`,
  );
  return result.rows;
}

async function findGame(client: PoolClient, gameKey: string): Promise<GameRow> {
  const result = await client.query<GameRow>(
    `SELECT id, name, slug, difficulty
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

function present(
  user: { id: string; username: string; email: string },
  game: GameRow,
  row: ProfileRow | undefined,
): PlayerGameProfile {
  const assigned = row && row.profile !== "DEFAULT";
  const stored = row?.parameters && typeof row.parameters === "object" ? row.parameters : {};
  const parameters = assigned
    ? Object.fromEntries(
        parametersForSlug(game.slug).map((definition) => [
          definition.key,
          clampParameter(game.slug, definition.key, stored[definition.key]),
        ]),
      )
    : defaultParameters(game.slug);
  return {
    userId: user.id,
    username: user.username,
    email: user.email,
    gameId: game.id,
    slug: game.slug,
    gameName: game.name,
    gameDifficulty: game.difficulty,
    assignedProfile: assigned && row ? row.profile : "DEFAULT",
    parameters,
    parameterDefs: parametersForSlug(game.slug),
    updatedAt: assigned && row ? row.updated_at.toISOString() : null,
  };
}
