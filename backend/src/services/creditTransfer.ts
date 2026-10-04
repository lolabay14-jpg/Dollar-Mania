import type { PoolClient } from "pg";
import { pool, withTransaction } from "../db";
import { AppError } from "../errors";
import type { AppRole } from "../middleware/authenticate";

type Account = {
  id: string;
  username: string;
  role: AppRole;
  balance: number;
};

export async function moveCredits(input: {
  actorId: string;
  targetId: string;
  amount: number;
  action: "transfer" | "reclaim";
  note?: string;
  requestId?: string;
}) {
  if (!Number.isInteger(input.amount) || input.amount <= 0 || input.amount > 1_000_000) {
    throw new AppError(400, "Invalid amount.");
  }
  if (input.actorId === input.targetId) {
    throw new AppError(400, "You cannot change your own credits.");
  }
  try {
    return await withTransaction((client) => applyCreditMove(client, input));
  } catch (error) {
    if (input.requestId && isRequestConflict(error)) {
      const current = await readBalances(input.actorId, input.targetId);
      return { ...current, duplicate: true };
    }
    throw error;
  }
}

export async function applyCreditMove(
  client: PoolClient,
  input: {
    actorId: string;
    targetId: string;
    amount: number;
    action: "transfer" | "reclaim";
    note?: string;
    requestId?: string;
  },
) {
  if (input.requestId) {
    const existing = await client.query("SELECT id FROM credit_transactions WHERE request_id = $1", [
      input.requestId,
    ]);
    if (existing.rowCount) {
      const actor = await readBalance(client, input.actorId);
      const target = await readBalance(client, input.targetId);
      return { balance: target, senderBalance: actor, duplicate: true };
    }
  }

  const pair = await lockPair(client, input.actorId, input.targetId);
  const actor = pair.get(input.actorId);
  const target = pair.get(input.targetId);
  if (!actor || !target) {
    throw new AppError(404, "That account could not be found.");
  }
  assertMove(actor.role, target.role, input.action);
  const issuer = actor.role === "SUPER_ADMIN";

  if (issuer) {
    return issueCredits(client, actor, target, input);
  }

  const sender = input.action === "transfer" ? actor : target;
  const receiver = input.action === "transfer" ? target : actor;
  if (sender.balance < input.amount) {
    throw new AppError(400, "Insufficient credits.");
  }

  const senderBalance = await changeBalance(client, sender.id, -input.amount);
  const receiverBalance = await changeBalance(client, receiver.id, input.amount);
  const debitId = await writeLeg(
    client,
    sender.id,
    -input.amount,
    senderBalance,
    "ADMIN_REMOVE",
    input.actorId,
    input.requestId,
  );
  const creditId = await writeLeg(
    client,
    receiver.id,
    input.amount,
    receiverBalance,
    "ADMIN_ADD",
    input.actorId,
    null,
  );
  await recordActivity(client, input.actorId, input.targetId, input.action, input.amount);

  const targetBalance = input.action === "transfer" ? receiverBalance : senderBalance;
  const actorBalance = input.action === "transfer" ? senderBalance : receiverBalance;
  return {
    transactionId: input.action === "transfer" ? creditId : debitId,
    creditTransactionId: creditId,
    senderId: sender.id,
    receiverId: receiver.id,
    amount: input.amount,
    balance: targetBalance,
    senderBalance: actorBalance,
    receiverBalance,
    issuer: false,
    status: "COMPLETED",
    duplicate: false,
  };
}

async function issueCredits(
  client: PoolClient,
  actor: Account,
  target: Account,
  input: {
    actorId: string;
    targetId: string;
    amount: number;
    action: "transfer" | "reclaim";
    requestId?: string;
  },
) {
  const delta = input.action === "transfer" ? input.amount : -input.amount;
  if (delta < 0 && target.balance < input.amount) {
    throw new AppError(400, "Insufficient credits.");
  }
  const targetBalance = await changeBalance(client, target.id, delta);
  const transactionId = await writeLeg(
    client,
    target.id,
    delta,
    targetBalance,
    delta > 0 ? "ADMIN_ADD" : "ADMIN_REMOVE",
    input.actorId,
    input.requestId,
  );
  await recordActivity(client, input.actorId, input.targetId, input.action, input.amount);
  return {
    transactionId,
    creditTransactionId: delta > 0 ? transactionId : null,
    senderId: actor.id,
    receiverId: target.id,
    amount: input.amount,
    balance: targetBalance,
    senderBalance: actor.balance,
    receiverBalance: targetBalance,
    issuer: true,
    status: "COMPLETED",
    duplicate: false,
  };
}

function assertMove(actorRole: AppRole, targetRole: AppRole, action: "transfer" | "reclaim") {
  if (targetRole === "SUPER_ADMIN" || actorRole === "PLAYER") {
    throw new AppError(403, "Unauthorized action.");
  }
  const allowed =
    actorRole === "SUPER_ADMIN"
      ? targetRole === "ADMIN" || targetRole === "PLAYER"
      : actorRole === "ADMIN" && targetRole === "PLAYER";
  if (!allowed) {
    throw new AppError(403, "Unauthorized action.");
  }
}

async function lockPair(client: PoolClient, firstId: string, secondId: string) {
  const ids = [firstId, secondId].sort();
  const accounts = new Map<string, Account>();
  for (const id of ids) {
    const user = await client.query<{ id: string; username: string; role: string }>(
      "SELECT id, username, role FROM users WHERE id = $1 FOR UPDATE",
      [id],
    );
    const row = user.rows[0];
    if (!row || !isRole(row.role)) {
      throw new AppError(404, "User not found.");
    }
    accounts.set(id, { id: row.id, username: row.username, role: row.role, balance: 0 });
  }
  for (const id of ids) {
    await client.query(
      "INSERT INTO wallets (user_id, balance) VALUES ($1, 0) ON CONFLICT (user_id) DO NOTHING",
      [id],
    );
  }
  for (const id of ids) {
    const wallet = await client.query<{ balance: number }>(
      "SELECT balance FROM wallets WHERE user_id = $1 FOR UPDATE",
      [id],
    );
    const account = accounts.get(id);
    if (!account || !wallet.rows[0]) {
      throw new AppError(404, "That account does not have a wallet.");
    }
    account.balance = Number(wallet.rows[0].balance);
  }
  return accounts;
}

async function changeBalance(client: PoolClient, userId: string, delta: number) {
  const updated = await client.query<{ balance: string }>(
    `UPDATE wallets
     SET balance = balance + $2, updated_at = now()
     WHERE user_id = $1 AND balance + $2 >= 0
     RETURNING balance`,
    [userId, delta],
  );
  const row = updated.rows[0];
  if (!row) {
    if (delta > 0) {
      throw new AppError(404, "Recipient wallet could not be found.");
    }
    throw new AppError(400, "Insufficient credits.");
  }
  return Number(row.balance);
}

async function recordActivity(
  client: PoolClient,
  actorId: string,
  targetId: string,
  action: "transfer" | "reclaim",
  amount: number,
) {
  await client.query(
    `INSERT INTO admin_activity (admin_user_id, target_user_id, action, amount)
     VALUES ($1, $2, $3, $4)`,
    [actorId, targetId, action === "transfer" ? "CREDIT_TRANSFER" : "CREDIT_RECLAIM", action === "transfer" ? amount : -amount],
  );
}

async function writeLeg(
  client: PoolClient,
  userId: string,
  amount: number,
  balanceAfter: number,
  transactionType: "ADMIN_ADD" | "ADMIN_REMOVE",
  actorId: string,
  requestId: string | null | undefined,
) {
  const inserted = await client.query<{ id: string }>(
    `INSERT INTO credit_transactions
       (user_id, amount, balance_after, transaction_type, description, created_by, request_id)
     VALUES ($1, $2, $3, $4, NULL, $5, $6)
     RETURNING id`,
    [userId, amount, balanceAfter, transactionType, actorId, requestId ?? null],
  );
  return inserted.rows[0].id;
}

async function readBalances(actorId: string, targetId: string) {
  return {
    senderBalance: await readBalance(pool, actorId),
    balance: await readBalance(pool, targetId),
  };
}

async function readBalance(db: PoolClient | typeof pool, userId: string) {
  const result = await db.query<{ balance: number }>("SELECT balance FROM wallets WHERE user_id = $1", [userId]);
  return Number(result.rows[0]?.balance ?? 0);
}

function isRole(role: string): role is AppRole {
  return role === "SUPER_ADMIN" || role === "ADMIN" || role === "PLAYER";
}

function isRequestConflict(error: unknown) {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    String(error.code) === "23505" &&
    "constraint" in error &&
    String(error.constraint).includes("request")
  );
}
