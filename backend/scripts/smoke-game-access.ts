import { pool } from "../src/db";
import {
  assertPlayerCanPlayGame,
  getDisabledGameIds,
  listPlayerGameAccess,
  setAllPlayerGameAccess,
  setPlayerGameAccess,
} from "../src/services/playerGameAccessService";
import { listGamesForPlayer } from "../src/services/slotService";

async function main() {
  const players = await pool.query<{ id: string; username: string }>(
    `SELECT id, username
     FROM users
     WHERE role = 'PLAYER' AND is_active = true
     ORDER BY created_at ASC
     LIMIT 2`,
  );
  const sa = await pool.query<{ id: string; username: string }>(
    `SELECT id, username
     FROM users
     WHERE role = 'SUPER_ADMIN' AND is_active = true
     ORDER BY created_at ASC
     LIMIT 1`,
  );
  const games = await pool.query<{ id: string; name: string; slug: string }>(
    `SELECT id, name, slug FROM slot_games WHERE is_active = true ORDER BY name ASC`,
  );
  if (players.rows.length < 2 || !sa.rows[0] || games.rows.length < 2) {
    throw new Error("Need 2 players, 1 super admin, and at least 2 active games");
  }

  const playerA = players.rows[0];
  const playerB = players.rows[1];
  const actor = sa.rows[0];
  const fish =
    games.rows.find((game) => game.slug === "fishing" || game.slug.includes("fish")) ?? games.rows[0];
  const other = games.rows.find((game) => game.id !== fish.id) ?? games.rows[1];

  await pool.query("DELETE FROM player_game_controls WHERE player_id = ANY($1::uuid[])", [
    [playerA.id, playerB.id],
  ]);

  const beforeA = await listPlayerGameAccess(playerA.id);
  if (beforeA.disabledCount !== 0) {
    throw new Error(`Expected default enabled for ${playerA.username}, got ${beforeA.disabledCount} disabled`);
  }

  await setPlayerGameAccess(actor.id, playerA.id, fish.id, false);
  const afterDisable = await listPlayerGameAccess(playerA.id);
  const fishRow = afterDisable.games.find((game) => game.gameId === fish.id);
  if (!fishRow || fishRow.enabled) {
    throw new Error(`Expected ${fish.name} disabled for ${playerA.username}`);
  }

  const disabledA = await getDisabledGameIds(playerA.id);
  if (!disabledA.has(fish.id)) {
    throw new Error("getDisabledGameIds missing disabled game for player A");
  }
  const disabledB = await getDisabledGameIds(playerB.id);
  if (disabledB.has(fish.id)) {
    throw new Error("Disabling for player A must not affect player B");
  }

  const lobbyA = await listGamesForPlayer(playerA.id);
  const lobbyFish = lobbyA.find((game) => game.id === fish.id);
  if (!lobbyFish || lobbyFish.enabled) {
    throw new Error("Player A lobby must mark disabled game as enabled=false");
  }
  const lobbyB = await listGamesForPlayer(playerB.id);
  const lobbyFishB = lobbyB.find((game) => game.id === fish.id);
  if (!lobbyFishB || !lobbyFishB.enabled) {
    throw new Error("Player B lobby must keep the game enabled");
  }

  const client = await pool.connect();
  try {
    await assertPlayerCanPlayGame(client, playerA.id, fish.id);
    throw new Error("assertPlayerCanPlayGame should reject disabled game for player A");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (!message.toLowerCase().includes("unavailable")) {
      throw error;
    }
  } finally {
    client.release();
  }

  const clientB = await pool.connect();
  try {
    await assertPlayerCanPlayGame(clientB, playerB.id, fish.id);
  } finally {
    clientB.release();
  }

  await setPlayerGameAccess(actor.id, playerA.id, other.id, false);
  await setAllPlayerGameAccess(actor.id, playerA.id, false);
  const allOff = await listPlayerGameAccess(playerA.id);
  if (allOff.enabledCount !== 0) {
    throw new Error(`Disable all failed: ${allOff.enabledCount} still enabled`);
  }

  await setAllPlayerGameAccess(actor.id, playerA.id, true);
  const allOn = await listPlayerGameAccess(playerA.id);
  if (allOn.disabledCount !== 0) {
    throw new Error(`Enable all failed: ${allOn.disabledCount} still disabled`);
  }

  const activity = await pool.query(
    `SELECT action, description
     FROM admin_activity
     WHERE admin_user_id = $1 AND target_user_id = $2
       AND action IN ('DISABLE_PLAYER_GAME', 'ENABLE_PLAYER_GAME', 'DISABLE_ALL_PLAYER_GAMES', 'ENABLE_ALL_PLAYER_GAMES')
     ORDER BY created_at DESC
     LIMIT 5`,
    [actor.id, playerA.id],
  );
  if (activity.rows.length === 0) {
    throw new Error("Expected activity log rows for game-access changes");
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        playerA: playerA.username,
        playerB: playerB.username,
        game: fish.name,
        activity: activity.rows[0],
        totals: { games: allOn.totalGames, enabled: allOn.enabledCount, disabled: allOn.disabledCount },
      },
      null,
      2,
    ),
  );
  await pool.end();
}

main().catch(async (error) => {
  console.error(error);
  await pool.end().catch(() => undefined);
  process.exit(1);
});
