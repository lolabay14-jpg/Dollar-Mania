import "dotenv/config";
import type { Server } from "node:http";
import { evaluateGrid, type SymbolId } from "../src/services/slotRules";

const failures: string[] = [];

function check(name: string, condition: boolean, detail = "") {
  if (condition) {
    console.log(`PASS ${name}`);
    return;
  }
  failures.push(detail ? `${name}: ${detail}` : name);
  console.log(`FAIL ${name}${detail ? ` — ${detail}` : ""}`);
}

function assertSlotMath() {
  const rules = {
    weights: { COIN: 1, DOLLAR: 1, STAR: 1, DIAMOND: 1, SEVEN: 1, BONUS: 1 },
    threeKind: { COIN: 3, DOLLAR: 5, STAR: 8, DIAMOND: 14, SEVEN: 25, BONUS: 40 },
    pair: { COIN: 1, DOLLAR: 2, STAR: 2, BONUS: 4 },
  };
  const triple = evaluateGrid(rules, [
    ["STAR", "SEVEN", "COIN"],
    ["DOLLAR", "SEVEN", "STAR"],
    ["BONUS", "SEVEN", "COIN"],
  ] as SymbolId[][]);
  check("three sevens pay 25x", triple.multiplier === 25);
  const pair = evaluateGrid(rules, [
    ["STAR", "COIN", "SEVEN"],
    ["DOLLAR", "COIN", "STAR"],
    ["BONUS", "DIAMOND", "SEVEN"],
  ] as SymbolId[][]);
  check("two coins pay 1x", pair.multiplier === 1 && pair.highlights.join(",") === "0,1");
  const loss = evaluateGrid(rules, [
    ["STAR", "COIN", "SEVEN"],
    ["DOLLAR", "STAR", "DIAMOND"],
    ["BONUS", "DIAMOND", "SEVEN"],
  ] as SymbolId[][]);
  check("mixed line pays 0", loss.multiplier === 0);
}

async function main() {
  assertSlotMath();
  if (!process.env.DATABASE_URL) {
    console.error("DATABASE_URL is missing. Add your Neon connection string to backend/.env and rerun.");
    process.exit(1);
  }

  const { createApp } = await import("../src/app");
  const app = createApp();
  const server: Server = await new Promise((resolve) => {
    const listening = app.listen(0, () => resolve(listening));
  });
  const address = server.address();
  const port = typeof address === "object" && address ? address.port : 0;
  const base = `http://127.0.0.1:${port}`;

  const adminLogin = await send(base, "POST", "/api/auth/login", {
    username: process.env.DEFAULT_ADMIN_USERNAME ?? "admin",
    password: process.env.DEFAULT_ADMIN_PASSWORD ?? "",
  });
  check("admin login", adminLogin.status === 200 && adminLogin.body.user?.role === "ADMIN");
  const adminToken = String(adminLogin.body.token ?? "");
  check("admin jwt present", adminToken.length > 20);

  const playerLogin = await send(base, "POST", "/api/auth/login", {
    username: process.env.DEFAULT_PLAYER_USERNAME ?? "player1",
    password: process.env.DEFAULT_PLAYER_PASSWORD ?? "",
  });
  check("player login", playerLogin.status === 200 && playerLogin.body.user?.role === "PLAYER");
  const playerToken = String(playerLogin.body.token ?? "");

  const wrong = await send(base, "POST", "/api/auth/login", {
    username: process.env.DEFAULT_PLAYER_USERNAME ?? "player1",
    password: "not-the-password",
  });
  check("wrong password", wrong.status === 401);

  const missingUser = await send(base, "POST", "/api/auth/login", {
    username: "nobody_here",
    password: "not-the-password",
  });
  check("invalid username", missingUser.status === 401);

  const stamp = Date.now();
  const registered = await send(base, "POST", "/api/auth/register", {
    username: `player_${stamp}`,
    email: `player_${stamp}@dollarmania.local`,
    password: "dev-player-pass",
    confirmPassword: "dev-player-pass",
    displayName: "Test Player",
  });
  check("public register closed", registered.status === 403);

  const registerAdmin = await send(base, "POST", "/api/auth/register", {
    username: `admin_${stamp}`,
    email: `admin_${stamp}@dollarmania.local`,
    password: "dev-player-pass",
    confirmPassword: "dev-player-pass",
    role: "ADMIN",
  });
  check("public register cannot create admin", registerAdmin.status === 403);

  const created = await send(
    base,
    "POST",
    "/api/admin/users",
    {
      username: `player_${stamp}`,
      email: `player_${stamp}@dollarmania.local`,
      password: "dev-player-pass",
      confirmPassword: "dev-player-pass",
      displayName: "Test Player",
      startingCredits: 0,
    },
    adminToken,
  );
  check("admin creates player", created.status === 201 && created.body.user?.role === "PLAYER");

  const createdAdmin = await send(
    base,
    "POST",
    "/api/admin/users",
    {
      username: `admin_${stamp}`,
      email: `admin_${stamp}@dollarmania.local`,
      password: "dev-player-pass",
      confirmPassword: "dev-player-pass",
      displayName: "Nope",
      startingCredits: 10,
      role: "ADMIN",
    },
    adminToken,
  );
  check("create player rejects admin role", createdAdmin.status === 400);

  const noToken = await send(base, "GET", "/api/player/wallet");
  check("missing jwt", noToken.status === 401);
  const badToken = await send(base, "GET", "/api/player/wallet", undefined, "not-a-jwt");
  check("invalid jwt", badToken.status === 401);

  const playerAdmin = await send(base, "GET", "/api/admin/users", undefined, playerToken);
  check("player blocked from admin", playerAdmin.status === 403);
  const adminUsers = await send(base, "GET", "/api/admin/users", undefined, adminToken);
  check("admin lists users", adminUsers.status === 200 && Array.isArray(adminUsers.body.users));
  const known = adminUsers.body.users?.find((user: { email?: string }) => user.email);
  const found = await send(
    base,
    "GET",
    `/api/admin/users/search?email=${encodeURIComponent(String(known?.email ?? ""))}`,
    undefined,
    adminToken,
  );
  check(
    "admin search by email",
    found.status === 200 &&
      found.body.user?.email === known?.email &&
      found.body.user?.username &&
      found.body.user?.role === "PLAYER" &&
      typeof found.body.user?.balance === "number",
  );
  const playerSearch = await send(
    base,
    "GET",
    `/api/admin/users/search?email=${encodeURIComponent(String(known?.email ?? "nobody@dollarmania.local"))}`,
    undefined,
    playerToken,
  );
  check("player cannot search users", playerSearch.status === 403);
  const missingEmail = await send(
    base,
    "GET",
    "/api/admin/users/search?email=missing-user@dollarmania.local",
    undefined,
    adminToken,
  );
  check("unknown email", missingEmail.status === 404);
  const badEmail = await send(base, "GET", "/api/admin/users/search?email=not-an-email", undefined, adminToken);
  check("invalid search email", badEmail.status === 400);
  const controlPlayer = await send(
    base,
    "GET",
    `/api/admin/users/player?email=${encodeURIComponent(`player_${stamp}@dollarmania.local`)}`,
    undefined,
    adminToken,
  );
  check(
    "game control finds player",
    controlPlayer.status === 200 &&
      controlPlayer.body.player?.username === `player_${stamp}` &&
      controlPlayer.body.player?.email === `player_${stamp}@dollarmania.local` &&
      typeof controlPlayer.body.player?.credits === "number" &&
      controlPlayer.body.player?.status === "Active" &&
      controlPlayer.body.player?.role === "PLAYER",
  );
  const missingPlayer = await send(
    base,
    "GET",
    "/api/admin/users/player?email=missing-player@dollarmania.local",
    undefined,
    adminToken,
  );
  check("player not found", missingPlayer.status === 404 && missingPlayer.body.error === "Player not found");
  const adminSelf = await send(base, "GET", `/api/admin/users/${adminLogin.body.user?.id}`, undefined, adminToken);
  const adminTarget = await send(
    base,
    "GET",
    `/api/admin/users/player?email=${encodeURIComponent(String(adminSelf.body.user?.email ?? ""))}`,
    undefined,
    adminToken,
  );
  check("admin cannot be a game control target", adminTarget.status === 400);
  const playerLookup = await send(
    base,
    "GET",
    `/api/admin/users/player?email=${encodeURIComponent(`player_${stamp}@dollarmania.local`)}`,
    undefined,
    playerToken,
  );
  check("player cannot search game control targets", playerLookup.status === 403);

  const ownProfile = await send(base, "GET", "/api/player/profile", undefined, playerToken);
  check("player reads own profile", ownProfile.status === 200 && ownProfile.body.profile?.username === (process.env.DEFAULT_PLAYER_USERNAME ?? "player1"));
  const otherId = adminUsers.body.users?.find((user: { username: string }) => user.username !== (process.env.DEFAULT_PLAYER_USERNAME ?? "player1"))?.id;
  const otherWallet = await send(base, "GET", `/api/admin/users/${otherId}`, undefined, playerToken);
  check("player cannot read another private account", otherWallet.status === 403);

  const newLogin = await send(base, "POST", "/api/auth/login", {
    username: `player_${stamp}`,
    password: "dev-player-pass",
  });
  const newToken = String(newLogin.body.token ?? "");
  const newId = String(newLogin.body.user?.id ?? "");

  const added = await send(base, "POST", `/api/admin/users/${newId}/credits`, { amount: 100, action: "add" }, adminToken);
  check("admin adds credits", added.status === 200 && added.body.balance === 100);
  const removedTooMuch = await send(
    base,
    "POST",
    `/api/admin/users/${newId}/credits`,
    { amount: 1000, action: "remove" },
    adminToken,
  );
  check("cannot remove more than balance", removedTooMuch.status === 400);
  const walletAfterReject = await send(base, "GET", "/api/player/wallet", undefined, newToken);
  check("balance unchanged after rejected remove", walletAfterReject.body.balance === 100);
  const removed = await send(base, "POST", `/api/admin/users/${newId}/credits`, { amount: 40, action: "remove" }, adminToken);
  check("admin removes credits", removed.status === 200 && removed.body.balance === 60);

  const transactions = await send(base, "GET", "/api/admin/transactions", undefined, adminToken);
  const ownTransactions = await send(base, "GET", "/api/player/transactions", undefined, newToken);
  check(
    "transactions recorded",
    ownTransactions.status === 200 &&
      ownTransactions.body.transactions?.some((row: { transactionType: string }) => row.transactionType === "ADMIN_ADD") &&
      ownTransactions.body.transactions?.some((row: { transactionType: string }) => row.transactionType === "ADMIN_REMOVE"),
  );
  const activity = await send(base, "GET", "/api/admin/activity", undefined, adminToken);
  check(
    "admin activity recorded",
    activity.status === 200 &&
      activity.body.activity?.some((row: { action: string; targetUsername: string }) => row.action === "ADMIN_ADD" && row.targetUsername === `player_${stamp}`),
  );
  check("admin transaction list", transactions.status === 200);

  const deactivated = await send(base, "PATCH", `/api/admin/users/${newId}`, { isActive: false }, adminToken);
  check("admin deactivates player", deactivated.status === 200 && deactivated.body.user?.isActive === false);
  const inactiveLogin = await send(base, "POST", "/api/auth/login", {
    username: `player_${stamp}`,
    password: "dev-player-pass",
  });
  check("inactive account rejected", inactiveLogin.status === 403);
  const inactiveSpin = await send(base, "POST", "/api/games/lucky-dollar/spin", { betAmount: 10 }, newToken);
  check("inactive token rejected", inactiveSpin.status === 403);
  await send(base, "PATCH", `/api/admin/users/${newId}`, { isActive: true }, adminToken);

  const lowBet = await send(base, "POST", "/api/games/golden-fortune/spin", { betAmount: 1 }, newToken);
  check("bet below minimum", lowBet.status === 400);
  const highBet = await send(base, "POST", "/api/games/lucky-dollar/spin", { betAmount: 500 }, newToken);
  check("bet above maximum", highBet.status === 400);
  const badBet = await send(base, "POST", "/api/games/lucky-dollar/spin", { betAmount: 0 }, newToken);
  check("invalid bet", badBet.status === 400);
  const negativeBet = await send(base, "POST", "/api/games/lucky-dollar/spin", { betAmount: -5 }, newToken);
  check("negative bet", negativeBet.status === 400);

  await send(base, "POST", `/api/admin/users/${newId}/credits`, { amount: 400, action: "add" }, adminToken);
  const games = await send(base, "GET", "/api/player/games", undefined, newToken);
  check("all active games", games.status === 200 && games.body.games?.length >= 11);
  check(
    "player games hide admin profiles",
    Array.isArray(games.body.games) &&
      games.body.games.every(
        (game: { assignedProfile?: string; parameterDefs?: unknown }) =>
          game.assignedProfile === undefined && game.parameterDefs === undefined,
      ),
  );
  const blockedProfile = await send(
    base,
    "PUT",
    `/api/admin/users/${newId}/game-profiles/coin-flip`,
    { profile: "MEDIUM", parameters: { rewardScale: 2, winChance: 60 } },
    newToken,
  );
  check("player cannot set game profile", blockedProfile.status === 403);
  const unknownParameter = await send(
    base,
    "PUT",
    `/api/admin/users/${newId}/game-profiles/coin-flip`,
    { profile: "MEDIUM", parameters: { winAmount: 100, rewardScale: 1, winChance: 47 } },
    adminToken,
  );
  check("unknown game parameter rejected", unknownParameter.status === 400);
  const wideScale = await send(
    base,
    "PUT",
    `/api/admin/users/${newId}/game-profiles/coin-flip`,
    { profile: "MEDIUM", parameters: { rewardScale: 9, winChance: 47 } },
    adminToken,
  );
  check("reward scale out of range", wideScale.status === 400);
  await send(
    base,
    "PUT",
    `/api/admin/users/${newId}/game-profiles/coin-flip`,
    { profile: "EASY", parameters: { rewardScale: 1, winChance: 47 } },
    adminToken,
  );
  const assigned = await send(
    base,
    "PUT",
    `/api/admin/users/${newId}/game-profiles/coin-flip`,
    { profile: "MEDIUM", parameters: { rewardScale: 2, winChance: 60 } },
    adminToken,
  );
  const profileList = await send(base, "GET", `/api/admin/users/${newId}/game-profiles`, undefined, adminToken);
  const coinProfiles = (profileList.body.profiles ?? []).filter(
    (row: { slug: string }) => row.slug === "coin-flip",
  );
  check(
    "one game profile per player",
    assigned.status === 200 &&
      coinProfiles.length === 1 &&
      coinProfiles[0].assignedProfile === "MEDIUM" &&
      coinProfiles[0].parameters?.rewardScale === 2 &&
      coinProfiles[0].parameters?.winChance === 60 &&
      coinProfiles[0].gameDifficulty === "MEDIUM",
  );
  let scaledWin = false;
  for (let attempt = 0; attempt < 15 && !scaledWin; attempt += 1) {
    const scaled = await send(
      base,
      "POST",
      "/api/games/coin-flip/spin",
      { betAmount: 10, choice: "HEADS", winAmount: 99999 },
      newToken,
    );
    if (scaled.status !== 200) {
      check("profiled coin spin", false, JSON.stringify(scaled.body));
      break;
    }
    const win = Number(scaled.body.winAmount);
    if (win === 0) {
      continue;
    }
    scaledWin = win === 38;
    check("profile reward scale applied", scaledWin, `win ${win}`);
    break;
  }
  check("scaled coin win observed", scaledWin);
  const resetProfile = await send(
    base,
    "PUT",
    `/api/admin/users/${newId}/game-profiles/coin-flip`,
    { profile: "DEFAULT" },
    adminToken,
  );
  const resetList = await send(base, "GET", `/api/admin/users/${newId}/game-profiles`, undefined, adminToken);
  const resetCoin = (resetList.body.profiles ?? []).find((row: { slug: string }) => row.slug === "coin-flip");
  check(
    "game profile reset",
    resetProfile.status === 200 && resetCoin?.assignedProfile === "DEFAULT" && resetCoin?.parameters?.rewardScale === 1,
  );
  const profileActivity = await send(base, "GET", "/api/admin/activity", undefined, adminToken);
  check(
    "game profile activity recorded",
    profileActivity.body.activity?.some(
      (row: { action: string; targetUsername: string }) =>
        row.action === "SET_GAME_PROFILE" && row.targetUsername === `player_${stamp}`,
    ) &&
      profileActivity.body.activity?.some(
        (row: { action: string; targetUsername: string }) =>
          row.action === "RESET_GAME_PROFILE" && row.targetUsername === `player_${stamp}`,
      ),
  );
  const expectedGames: Record<string, [string, string, number, number]> = {
    "lucky-dollar": ["EASY", "SLOTS", 1, 100],
    "golden-fortune": ["MEDIUM", "SLOTS", 5, 500],
    "dollar-rush": ["HARD", "REACTION", 10, 1000],
    "scratch-mania": ["EASY", "SCRATCH", 2, 50],
    "lucky-spin": ["EASY", "SPIN", 5, 100],
    "coin-flip": ["MEDIUM", "CHOICE", 10, 200],
    "treasure-box": ["MEDIUM", "CHOICE", 5, 150],
    "cash-match": ["MEDIUM", "MATCH", 5, 150],
    "diamond-drop": ["HARD", "MATCH", 10, 400],
    "bonus-burst": ["MEDIUM", "BONUS", 10, 250],
    "jackpot-wheel": ["HARD", "SPIN", 20, 500],
    "higher-card": ["EASY", "CARDS", 5, 200],
    "fruit-spin": ["MEDIUM", "SPIN", 5, 100],
    "lucky-wheel": ["MEDIUM", "SPIN", 5, 200],
    "prize-spinner": ["MEDIUM", "SPIN", 5, 150],
    "fishing": ["MEDIUM", "FISHING", 5, 100],
    "dice": ["MEDIUM", "CHOICE", 5, 100],
    "lucky-number": ["MEDIUM", "MATCH", 5, 100],
  };
  for (const game of games.body.games ?? []) {
    const spec = expectedGames[game.slug];
    if (!spec) continue;
    check(
      `${game.slug} config`,
      game.difficulty === spec[0] &&
        game.category === spec[1] &&
        Number(game.minimumBet) === spec[2] &&
        Number(game.maximumBet) === spec[3],
    );
  }
  const requestId = `verify-${stamp}`.slice(0, 80);
  const firstPlay = await send(base, "POST", "/api/games/lucky-dollar/spin", { betAmount: 10, requestId }, newToken);
  const replay = await send(base, "POST", "/api/games/lucky-dollar/spin", { betAmount: 10, requestId, winAmount: 99999 }, newToken);
  check(
    "replayed play is not paid twice",
    firstPlay.status === 200 && replay.status === 200 && replay.body.playId === firstPlay.body.playId && replay.body.balance === firstPlay.body.balance,
  );
  const rushed = await send(base, "POST", "/api/games/dollar-rush/spin", { betAmount: 10 }, newToken);
  check("rush requires a lane", rushed.status === 400);
  const coin = await send(base, "POST", "/api/games/coin-flip/spin", { betAmount: 10, choice: "HEADS", winAmount: 99999 }, newToken);
  check(
    "coin result ignores client winnings",
    coin.status === 200 && Number(coin.body.winAmount) <= 19 && coin.body.presentation?.face,
  );
  const missing = await send(base, "POST", "/api/games/not-a-real-game/spin", { betAmount: 10 }, newToken);
  check("unknown game rejected", missing.status === 404);
  let sawWin = false;
  let sawLoss = false;
  let lastBalance = 0;
  for (let index = 0; index < 24 && (!sawWin || !sawLoss); index += 1) {
    const before = await send(base, "GET", "/api/player/wallet", undefined, newToken);
    const spin = await send(base, "POST", "/api/games/lucky-dollar/spin", { betAmount: 10 }, newToken);
    if (spin.status !== 200) {
      check("valid spin", false, JSON.stringify(spin.body));
      break;
    }
    const expected = Number(before.body.balance) - 10 + Number(spin.body.winAmount);
    check(`spin balance ${index}`, Number(spin.body.balance) === expected, `expected ${expected} got ${spin.body.balance}`);
    check(`spin result shape ${index}`, Array.isArray(spin.body.result) && spin.body.result.length === 3);
    if (Number(spin.body.winAmount) > 0) {
      sawWin = true;
    } else {
      sawLoss = true;
    }
    lastBalance = Number(spin.body.balance);
  }
  check("successful win observed", sawWin);
  check("losing spin observed", sawLoss);

  const history = await send(base, "GET", "/api/player/spins", undefined, newToken);
  check("spin history", history.status === 200 && history.body.spins?.length > 0);
  const wallet = await send(base, "GET", "/api/player/wallet", undefined, newToken);
  check("wallet matches last spin", wallet.body.balance === lastBalance);
  const ledger = await send(base, "GET", "/api/player/transactions", undefined, newToken);
  check(
    "spin ledger",
    ledger.body.transactions?.some((row: { transactionType: string }) => row.transactionType === "GAME_BET"),
  );

  const beforeRequest = await send(base, "GET", "/api/player/wallet", undefined, newToken);
  const creditRequest = await send(base, "POST", "/api/player/credit-requests", { amount: 25 }, newToken);
  const afterRequest = await send(base, "GET", "/api/player/wallet", undefined, newToken);
  check(
    "player credit request does not change balance",
    creditRequest.status === 201 &&
      creditRequest.body.request?.status === "PENDING" &&
      afterRequest.body.balance === beforeRequest.body.balance,
  );
  const duplicateRequest = await send(base, "POST", "/api/player/credit-requests", { amount: 25 }, newToken);
  check("one pending credit request", duplicateRequest.status === 409);
  const ownRequests = await send(base, "GET", "/api/player/credit-requests", undefined, newToken);
  check(
    "player sees request status",
    ownRequests.status === 200 && ownRequests.body.requests?.some((row: { status: string }) => row.status === "PENDING"),
  );
  const blockedReview = await send(
    base,
    "POST",
    `/api/admin/credit-requests/${creditRequest.body.request?.id}/review`,
    { action: "approve" },
    newToken,
  );
  check("player cannot approve credits", blockedReview.status === 403);
  const approved = await send(
    base,
    "POST",
    `/api/admin/credit-requests/${creditRequest.body.request?.id}/review`,
    { action: "approve" },
    adminToken,
  );
  const funded = await send(base, "GET", "/api/player/wallet", undefined, newToken);
  check(
    "admin approval adds credits",
    approved.status === 200 && Number(funded.body.balance) === Number(beforeRequest.body.balance) + 25,
  );

  await send(base, "POST", `/api/admin/users/${newId}/credits`, { amount: funded.body.balance, action: "remove" }, adminToken);
  const broke = await send(base, "POST", "/api/games/lucky-dollar/spin", { betAmount: 10 }, newToken);
  check("insufficient credits", broke.status === 400 && broke.body.error === "Insufficient credits");
  const stillBroke = await send(base, "GET", "/api/player/wallet", undefined, newToken);
  check("insufficient spin does not change balance", stillBroke.body.balance === 0);

  await new Promise<void>((resolve) => server.close(() => resolve()));
  const { pool } = await import("../src/db");
  await pool.end();
  if (failures.length) {
    console.error(`FAILED ${failures.length}`);
    process.exit(1);
  }
  console.log("API_CHECK_OK");
}

async function send(base: string, method: string, path: string, body?: unknown, token?: string) {
  const headers: Record<string, string> = { Accept: "application/json" };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  let payload: string | undefined;
  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }
  const response = await fetch(`${base}${path}`, { method, headers, body: payload });
  const text = await response.text();
  let parsed: Record<string, any> = {};
  if (text) {
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = { error: text };
    }
  }
  return { status: response.status, body: parsed };
}

main().catch(async (error: unknown) => {
  const message = error instanceof Error ? error.message : "Verification failed.";
  console.error(message.replace(/postgres(?:ql)?:\/\/\S+/gi, "[redacted]"));
  process.exit(1);
});
