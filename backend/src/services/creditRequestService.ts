import { pool, withTransaction } from "../db";
import { AppError } from "../errors";

export async function createCreditRequest(userId: string, amount: number) {
  try {
    const created = await pool.query(
      `INSERT INTO credit_requests (user_id, requested_amount, status)
       VALUES ($1, $2, 'PENDING')
       RETURNING id, requested_amount, status, created_at`,
      [userId, amount],
    );
    return mapRequest(created.rows[0]);
  } catch (error) {
    if (isUniqueViolation(error)) {
      throw new AppError(409, "You already have a credit request waiting for review.");
    }
    throw error;
  }
}

export async function listOwnCreditRequests(userId: string) {
  const result = await pool.query(
    `SELECT id, user_id, requested_amount, status, created_at, reviewed_at, admin_note
     FROM credit_requests
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT 20`,
    [userId],
  );
  return result.rows.map(mapRequest);
}

export async function listCreditRequests() {
  const result = await pool.query(
    `SELECT r.id, r.user_id, u.username, r.requested_amount, r.status, r.created_at, r.reviewed_at, r.admin_note
     FROM credit_requests r
     JOIN users u ON u.id = r.user_id
     ORDER BY CASE r.status WHEN 'PENDING' THEN 0 ELSE 1 END, r.created_at DESC
     LIMIT 40`,
  );
  return result.rows.map((row) => ({
    ...mapRequest(row),
    username: row.username as string,
  }));
}

export async function reviewCreditRequest(
  adminId: string,
  requestId: string,
  action: "approve" | "reject",
  note: string,
) {
  return withTransaction(async (client) => {
    const found = await client.query(
      `SELECT id, user_id, requested_amount, status
       FROM credit_requests
       WHERE id = $1
       FOR UPDATE`,
      [requestId],
    );
    const request = found.rows[0];
    if (!request) {
      throw new AppError(404, "That credit request was not found.");
    }
    if (request.status !== "PENDING") {
      throw new AppError(400, "That credit request was already reviewed.");
    }
    let balance: number | null = null;
    if (action === "approve") {
      const amount = Number(request.requested_amount);
      const locked = await client.query<{ balance: string }>(
        "SELECT balance FROM wallets WHERE user_id = $1 FOR UPDATE",
        [request.user_id],
      );
      if (!locked.rows[0]) {
        throw new AppError(404, "That player does not have a wallet.");
      }
      balance = Math.round((Number(locked.rows[0].balance) + amount) * 100) / 100;
      await client.query("UPDATE wallets SET balance = $2, updated_at = now() WHERE user_id = $1", [
        request.user_id,
        balance,
      ]);
      await client.query(
        `INSERT INTO credit_transactions
           (user_id, amount, balance_after, transaction_type, description, created_by)
         VALUES ($1, $2, $3, 'ADMIN_ADD', $4, $5)`,
        [request.user_id, amount, balance, "Approved credit request", adminId],
      );
      await client.query(
        `INSERT INTO admin_activity (admin_user_id, target_user_id, action, amount, description)
         VALUES ($1, $2, 'ADMIN_ADD', $3, $4)`,
        [adminId, request.user_id, amount, "Approved credit request"],
      );
    }
    const status = action === "approve" ? "APPROVED" : "REJECTED";
    const updated = await client.query(
      `UPDATE credit_requests
       SET status = $2, reviewed_at = now(), reviewed_by = $3, admin_note = $4
       WHERE id = $1
       RETURNING id, user_id, requested_amount, status, created_at, reviewed_at, admin_note`,
      [requestId, status, adminId, note || null],
    );
    return { request: mapRequest(updated.rows[0]), balance };
  });
}

function mapRequest(row: {
  id: string;
  user_id?: string;
  requested_amount: string | number;
  status: string;
  created_at: Date;
  reviewed_at?: Date | null;
  admin_note?: string | null;
}) {
  return {
    id: row.id,
    userId: row.user_id,
    amount: Number(row.requested_amount),
    status: row.status,
    createdAt: row.created_at,
    reviewedAt: row.reviewed_at ?? null,
    note: row.admin_note ?? "",
  };
}

function isUniqueViolation(error: unknown) {
  return typeof error === "object" && error !== null && "code" in error && error.code === "23505";
}
