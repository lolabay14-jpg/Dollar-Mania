import "dotenv/config";
import type { Server } from "node:http";
import { createApp } from "../src/app";
import { pool } from "../src/db";
import { resolveRound } from "../src/services/gamePlay";

const REQUIRED = [
  "fruit-spin",
  "diamond-spin",
  "lucky-dollar",
  "scratch-mania",
  "lucky-wheel",
  "coin-flip",
  "treasure-box",
  "cash-match",
  "diamond-drop",
  "bonus-burst",
  "jackpot-wheel",
  "mystery-box",
  "dollar-rush",
  "fishing",
  "target-blast",
  "aeroplane-rush",
  "bottle-blast",
];

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
  for (const slug of REQUIRED) {
    let choice: unknown;
    if (slug === "dollar-rush" || slug === "treasure-box" || slug === "lucky-number") {
      choice = 1;
    } else if (slug === "coin-flip") {
      choice = "HEADS";
    }
    const round = resolveRound(slug, choice, "MEDIUM", {});
    if (!round || typeof round.multiplier !== "number" || !round.presentation) {
      throw new Error(`resolveRound failed for ${slug}`);
    }
    console.log(`RESOLVE OK ${slug} kind=${String(round.presentation.kind ?? "?")} x${round.multiplier}`);
  }

  const app = createApp();
  const server: Server = await new Promise((resolve) => {
    const listening = app.listen(0, () => resolve(listening));
  });
  const port = (server.address() as { port: number }).port;
  const base = `http://127.0.0.1:${port}`;
  const login = await send(base, "POST", "/api/auth/login", {
    username: process.env.DEFAULT_PLAYER_USERNAME ?? "player1",
    password: process.env.DEFAULT_PLAYER_PASSWORD ?? "",
  });
  if (login.status !== 200) {
    throw new Error(`player login failed ${login.status}`);
  }
  const token = String(login.body.token ?? "");
  const games = await send(base, "GET", "/api/player/games", undefined, token);
  const list = Array.isArray(games.body.games) ? (games.body.games as Array<{ id: string; slug: string; minimumBet?: number; enabled?: boolean }>) : [];
  if (list.length < REQUIRED.length) {
    throw new Error(`Expected at least ${REQUIRED.length} games, got ${list.length}`);
  }

  const playerName = process.env.DEFAULT_PLAYER_USERNAME ?? "player1";
  // Ensure required games are enabled and the player has enough credits for a full audit.
  await pool.query("DELETE FROM player_game_controls WHERE player_id = (SELECT id FROM users WHERE username = $1)", [
    playerName,
  ]);
  await pool.query(
    `UPDATE wallets
     SET balance = GREATEST(balance, 5000)
     WHERE user_id = (SELECT id FROM users WHERE username = $1)`,
    [playerName],
  );

  for (const slug of REQUIRED) {
    const game = list.find((item) => item.slug === slug);
    if (!game) {
      throw new Error(`Missing game in lobby: ${slug}`);
    }
    const bet = Math.max(1, Number(game.minimumBet) || 1);
    const body: Record<string, unknown> = { betAmount: bet, requestId: `smoke-${slug}-${Date.now()}` };
    if (slug === "dollar-rush" || slug === "treasure-box") {
      body.choice = 1;
    } else if (slug === "coin-flip") {
      body.choice = "HEADS";
    }
    const spin = await send(base, "POST", `/api/games/${game.id}/spin`, body, token);
    if (spin.status !== 200) {
      throw new Error(`Spin failed for ${slug}: ${spin.status} ${JSON.stringify(spin.body)}`);
    }
    console.log(`SPIN OK ${slug}`);
  }

  // Password min length 4
  const shortPass = await send(base, "POST", "/api/auth/login", {
    username: process.env.DEFAULT_ADMIN_USERNAME ?? "admin",
    password: process.env.DEFAULT_ADMIN_PASSWORD ?? "",
  });
  const adminToken = String(shortPass.body.token ?? "");
  const createReject = await send(
    base,
    "POST",
    "/api/admin/users",
    {
      username: `tmp_${Date.now().toString().slice(-6)}`,
      email: `tmp_${Date.now()}@example.com`,
      password: "abc",
      confirmPassword: "abc",
      startingCredits: 0,
    },
    adminToken,
  );
  if (createReject.status === 201) {
    throw new Error("3-char password should be rejected");
  }
  console.log(`PASSWORD REJECT OK status=${createReject.status}`);

  const okName = `ok_${Date.now().toString().slice(-6)}`;
  const createAccept = await send(
    base,
    "POST",
    "/api/admin/users",
    {
      username: okName,
      email: `${okName}@example.com`,
      password: "abcd",
      confirmPassword: "abcd",
      // Password-rule checks only — do not spend admin wallet credits.
      startingCredits: 0,
    },
    adminToken,
  );
  if (createAccept.status !== 201) {
    throw new Error(`4-char password should be accepted: ${createAccept.status} ${JSON.stringify(createAccept.body)}`);
  }
  console.log("PASSWORD ACCEPT OK");

  // Cleanup created player
  await pool.query("DELETE FROM users WHERE username = $1", [okName]);

  // Change-password for the authenticated player (own account only).
  const pwUser = `pw_${Date.now().toString().slice(-6)}`;
  const createPw = await send(
    base,
    "POST",
    "/api/admin/users",
    {
      username: pwUser,
      email: `${pwUser}@example.com`,
      password: "old1",
      confirmPassword: "old1",
      startingCredits: 0,
    },
    adminToken,
  );
  if (createPw.status !== 201) {
    throw new Error(`change-password setup failed: ${createPw.status} ${JSON.stringify(createPw.body)}`);
  }
  const pwLogin = await send(base, "POST", "/api/auth/login", { username: pwUser, password: "old1" });
  if (pwLogin.status !== 200) {
    throw new Error(`change-password login failed: ${pwLogin.status}`);
  }
  const pwToken = String(pwLogin.body.token ?? "");
  const rejectShort = await send(
    base,
    "POST",
    "/api/auth/change-password",
    { currentPassword: "old1", newPassword: "abc", confirmPassword: "abc" },
    pwToken,
  );
  if (rejectShort.status === 200) {
    throw new Error("change-password should reject 3-char new password");
  }
  console.log(`CHANGE PW REJECT OK status=${rejectShort.status}`);
  const rejectWrong = await send(
    base,
    "POST",
    "/api/auth/change-password",
    { currentPassword: "wrong", newPassword: "new1", confirmPassword: "new1" },
    pwToken,
  );
  if (rejectWrong.status === 200) {
    throw new Error("change-password should reject wrong current password");
  }
  console.log(`CHANGE PW WRONG OK status=${rejectWrong.status}`);
  const changeOk = await send(
    base,
    "POST",
    "/api/auth/change-password",
    { currentPassword: "old1", newPassword: "new1", confirmPassword: "new1" },
    pwToken,
  );
  if (changeOk.status !== 200) {
    throw new Error(`change-password failed: ${changeOk.status} ${JSON.stringify(changeOk.body)}`);
  }
  const freshToken = String(changeOk.body.token ?? "");
  if (!freshToken) {
    throw new Error("change-password should return a fresh token");
  }
  const oldLogin = await send(base, "POST", "/api/auth/login", { username: pwUser, password: "old1" });
  if (oldLogin.status === 200) {
    throw new Error("old password should no longer work");
  }
  const newLogin = await send(base, "POST", "/api/auth/login", { username: pwUser, password: "new1" });
  if (newLogin.status !== 200) {
    throw new Error(`new password login failed: ${newLogin.status}`);
  }
  console.log("CHANGE PASSWORD OK");
  await pool.query("DELETE FROM users WHERE username = $1", [pwUser]);

  server.close();
  await pool.end();
  console.log("ALL GAME SMOKE PASSED");
}

main().catch(async (error) => {
  console.error(error);
  await pool.end().catch(() => undefined);
  process.exit(1);
});
