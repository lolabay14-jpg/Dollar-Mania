import { pool, withTransaction } from "../db";
import { AppError } from "../errors";
import { applyCreditMove } from "./creditTransfer";

export async function createCreditRequest(userId: string, amount: number, requestNote = "") {
  try {
    const created = await pool.query(
      `INSERT INTO credit_requests (user_id, requested_amount, status, request_note)
       VALUES ($1, $2, 'PENDING', $3)
       RETURNING id, user_id, requested_amount, status, created_at, reviewed_at, admin_note, request_note`,
      [userId, amount, requestNote || null],
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
    `SELECT id, user_id, requested_amount, status, created_at, reviewed_at, admin_note, request_note
     FROM credit_requests
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT 20`,
    [userId],
  );
  return result.rows.map(mapRequest);
}

export async function listCreditRequests(
  audience: "PLAYER" | "ADMIN" | "ALL" = "ALL",
  status: "PENDING" | "APPROVED" | "REJECTED" | "ALL" = "ALL",
) {
  const result = await pool.query(
    `SELECT r.id, r.user_id, u.username, u.email, u.role, COALESCE(w.balance, 0) AS balance,
            r.requested_amount, r.status, r.created_at, r.reviewed_at, r.admin_note, r.request_note
     FROM credit_requests r
     JOIN users u ON u.id = r.user_id
     LEFT JOIN wallets w ON w.user_id = u.id
     WHERE ($1 = 'ALL' OR u.role::text = $1)
       AND ($2 = 'ALL' OR r.status::text = $2)
     ORDER BY CASE r.status WHEN 'PENDING' THEN 0 ELSE 1 END, r.created_at DESC
     LIMIT 60`,
    [audience, status],
  );
  return result.rows.map((row) => ({
    ...mapRequest(row),
    username: row.username as string,
    email: (row.email as string) ?? "",
    role: row.role as string,
    balance: Number(row.balance),
  }));
}

export async function countPendingCreditRequests(audience: "PLAYER" | "ADMIN" | "ALL" = "ALL") {
  const result = await pool.query<{ total: number }>(
    `SELECT COUNT(*)::int AS total
     FROM credit_requests r
     JOIN users u ON u.id = r.user_id
     WHERE r.status = 'PENDING'
       AND ($1 = 'ALL' OR u.role::text = $1)`,
    [audience],
  );
  return Number(result.rows[0]?.total ?? 0);
}

export async function reviewCreditRequest(
  adminId: string,
  reviewerRole: "ADMIN" | "SUPER_ADMIN",
  requestId: string,
  action: "approve" | "reject",
  note: string,
) {
  return withTransaction(async (client) => {
    const found = await client.query(
      `SELECT r.id, r.user_id, r.requested_amount, r.status, u.role
       FROM credit_requests r
       JOIN users u ON u.id = r.user_id
       WHERE r.id = $1
       FOR UPDATE`,
      [requestId],
    );
    const request = found.rows[0];
    if (!request) {
      throw new AppError(404, "That credit request was not found.");
    }
    if (request.user_id === adminId) {
      throw new AppError(403, "You cannot review your own credit request.");
    }
    if (reviewerRole === "ADMIN" && request.role !== "PLAYER") {
      throw new AppError(403, "Only a super admin can review an admin credit request.");
    }
    if (request.status !== "PENDING") {
      throw new AppError(400, "That credit request was already reviewed.");
    }
    let balance: number | null = null;
    if (action === "approve") {
      const amount = Number(request.requested_amount);
      const moved = await applyCreditMove(client, {
        actorId: adminId,
        targetId: request.user_id,
        amount,
        action: "transfer",
        note: "Approved credit request",
      });
      balance = moved.balance;
    } else {
      await client.query(
        `INSERT INTO admin_activity (admin_user_id, target_user_id, action, amount, description)
         VALUES ($1, $2, 'CREDIT_REQUEST_REJECT', $3, $4)`,
        [adminId, request.user_id, Number(request.requested_amount), note || "Rejected credit request"],
      );
    }
    const status = action === "approve" ? "APPROVED" : "REJECTED";
    const updated = await client.query(
      `UPDATE credit_requests
       SET status = $2, reviewed_at = now(), reviewed_by = $3, admin_note = $4
       WHERE id = $1 AND status = 'PENDING'
       RETURNING id, user_id, requested_amount, status, created_at, reviewed_at, admin_note, request_note`,
      [requestId, status, adminId, note || null],
    );
    if (!updated.rows[0]) {
      throw new AppError(400, "That credit request was already reviewed.");
    }
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
  request_note?: string | null;
}) {
  return {
    id: row.id,
    userId: row.user_id,
    amount: Number(row.requested_amount),
    status: row.status,
    createdAt: row.created_at,
    reviewedAt: row.reviewed_at ?? null,
    note: row.admin_note ?? "",
    requestNote: row.request_note ?? "",
  };
}

function isUniqueViolation(error: unknown) {
  return typeof error === "object" && error !== null && "code" in error && error.code === "23505";
}
