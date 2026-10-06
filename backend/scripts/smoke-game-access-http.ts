import "dotenv/config";
import type { Server } from "node:http";
import { createApp } from "../src/app";
import { pool } from "../src/db";

async function send(base: string, method: string, path: string, body?: unknown, token?: string) {
  const response = await fetch(base + path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let parsed: Record<string, unknown> = {};
  try {
    parsed = JSON.parse(text) as Record<string, unknown>;
  } catch {
    parsed = { raw: text };
  }
  return { status: response.status, body: parsed };
}

async function main() {
  const app = createApp();
  const server: Server = await new Promise((resolve) => {
    const listening = app.listen(0, () => resolve(listening));
  });
  const address = server.address();
  const port = typeof address === "object" && address ? address.port : 0;
  const base = `http://127.0.0.1:${port}`;

  const saLogin = await send(base, "POST", "/api/auth/login", {
    username: process.env.SUPER_ADMIN_USERNAME ?? "superadmin",
    password: process.env.SUPER_ADMIN_PASSWORD ?? "",
  });
  const adminLogin = await send(base, "POST", "/api/auth/login", {
    username: process.env.ADMIN_USERNAME ?? process.env.DEFAULT_ADMIN_USERNAME ?? "admin",
    password: process.env.ADMIN_PASSWORD ?? process.env.DEFAULT_ADMIN_PASSWORD ?? "",
  });
  const playerLogin = await send(base, "POST", "/api/auth/login", {
    username: process.env.PLAYER_USERNAME ?? process.env.DEFAULT_PLAYER_USERNAME ?? "player1",
    password: process.env.PLAYER_PASSWORD ?? process.env.DEFAULT_PLAYER_PASSWORD ?? "",
  });

  const playerName = String(
    process.env.PLAYER_USERNAME ?? process.env.DEFAULT_PLAYER_USERNAME ?? "player1",
  );
  const playerRow = await pool.query<{ id: string }>("SELECT id FROM users WHERE username = $1", [playerName]);
  const fish = await pool.query<{ id: string; minimum_bet: number }>(
    "SELECT id, minimum_bet FROM slot_games WHERE slug = 'fishing' LIMIT 1",
  );
  if (!playerRow.rows[0] || !fish.rows[0]) {
    throw new Error("Missing player1 or fishing game");
  }
  const playerId = playerRow.rows[0].id;
  const gameId = fish.rows[0].id;
  const betAmount = Math.max(1, Number(fish.rows[0].minimum_bet) || 1);
  const saToken = String(saLogin.body.token ?? "");
  const adminToken = String(adminLogin.body.token ?? "");
  const playerToken = String(playerLogin.body.token ?? "");

  if (!saToken || String(saLogin.body.user && (saLogin.body.user as { role?: string }).role) !== "SUPER_ADMIN") {
    // Fall back to any SUPER_ADMIN credentials from DB if env defaults fail.
    const anySa = await pool.query<{ username: string }>(
      "SELECT username FROM users WHERE role = 'SUPER_ADMIN' AND is_active = true LIMIT 1",
    );
    throw new Error(`Super admin login failed (status ${saLogin.status}). Tried env user; DB has ${anySa.rows[0]?.username ?? "none"}`);
  }

  const deniedAdmin = await send(
    base,
    "PUT",
    `/api/admin/users/${playerId}/game-access/${gameId}`,
    { enabled: false },
    adminToken,
  );
  const deniedPlayer = await send(
    base,
    "PUT",
    `/api/admin/users/${playerId}/game-access/${gameId}`,
    { enabled: false },
    playerToken,
  );
  const search = await send(base, "GET", `/api/admin/game-access/search?q=${encodeURIComponent(playerName)}`, undefined, saToken);
  const disable = await send(
    base,
    "PUT",
    `/api/admin/users/${playerId}/game-access/${gameId}`,
    { enabled: false },
    saToken,
  );
  const games = await send(base, "GET", "/api/player/games", undefined, playerToken);
  const gameList = Array.isArray(games.body.games) ? (games.body.games as Array<{ id: string; enabled?: boolean }>) : [];
  const fishLobby = gameList.find((game) => game.id === gameId);
  const spin = await send(base, "POST", `/api/games/${gameId}/spin`, { betAmount }, playerToken);
  const enable = await send(
    base,
    "PUT",
    `/api/admin/users/${playerId}/game-access/${gameId}`,
    { enabled: true },
    saToken,
  );
  const spinOk = await send(base, "POST", `/api/games/${gameId}/spin`, { betAmount }, playerToken);

  const result = {
    adminDenied: deniedAdmin.status,
    playerDenied: deniedPlayer.status,
    searchStatus: search.status,
    disableStatus: disable.status,
    fishEnabledInLobby: fishLobby?.enabled,
    spinBlockedStatus: spin.status,
    spinBlockedError: spin.body.error,
    enableStatus: enable.status,
    spinAfterStatus: spinOk.status,
  };
  console.log(JSON.stringify(result, null, 2));

  if (deniedAdmin.status !== 403) throw new Error(`ADMIN should be 403, got ${deniedAdmin.status}`);
  if (deniedPlayer.status !== 403) throw new Error(`PLAYER should be 403, got ${deniedPlayer.status}`);
  if (search.status !== 200) throw new Error(`search failed ${search.status}`);
  if (disable.status !== 200) throw new Error(`disable failed ${disable.status}`);
  if (fishLobby?.enabled !== false) throw new Error("lobby should show fish disabled");
  if (spin.status !== 403) throw new Error(`spin should be 403, got ${spin.status}`);
  if (enable.status !== 200) throw new Error(`enable failed ${enable.status}`);
  if (spinOk.status !== 200) throw new Error(`spin after enable failed ${spinOk.status}`);

  server.close();
  await pool.end();
}

main().catch(async (error) => {
  console.error(error);
  await pool.end().catch(() => undefined);
  process.exit(1);
});
