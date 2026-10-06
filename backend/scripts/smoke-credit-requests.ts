import { pool } from "../src/db";
import {
  countPendingCreditRequests,
  createCreditRequest,
  listCreditRequests,
  reviewCreditRequest,
} from "../src/services/creditRequestService";

async function main() {
  const player = await pool.query(
    "SELECT id, username FROM users WHERE role='PLAYER' AND is_active=true ORDER BY created_at DESC LIMIT 1",
  );
  const admin = await pool.query(
    "SELECT id, username FROM users WHERE role='ADMIN' AND is_active=true ORDER BY created_at DESC LIMIT 1",
  );
  const sa = await pool.query(
    "SELECT id, username FROM users WHERE role='SUPER_ADMIN' AND is_active=true ORDER BY created_at DESC LIMIT 1",
  );
  if (!player.rows[0] || !admin.rows[0] || !sa.rows[0]) {
    throw new Error("Need active PLAYER, ADMIN, and SUPER_ADMIN accounts");
  }
  const pid = player.rows[0].id as string;
  const aid = admin.rows[0].id as string;
  const sid = sa.rows[0].id as string;

  await pool.query(
    `UPDATE credit_requests
     SET status = 'REJECTED', reviewed_at = now(), reviewed_by = $1
     WHERE user_id = ANY($2::uuid[]) AND status = 'PENDING'`,
    [sid, [pid, aid]],
  );

  // Ensure admin has credits for player approval transfer.
  await pool.query(
    `INSERT INTO wallets (user_id, balance) VALUES ($1, 500)
     ON CONFLICT (user_id) DO UPDATE SET balance = GREATEST(wallets.balance, 500)`,
    [aid],
  );

  const beforePlayer = await countPendingCreditRequests("PLAYER");
  const createdPlayer = await createCreditRequest(pid, 37, "verify player request");
  const playerList = await listCreditRequests("PLAYER", "PENDING");
  const afterPlayer = await countPendingCreditRequests("PLAYER");
  console.log("PLAYER_CREATE", createdPlayer.status, createdPlayer.amount, createdPlayer.requestNote);
  console.log(
    "ADMIN_SEES_PLAYER",
    playerList.some((row) => row.id === createdPlayer.id),
    "count",
    afterPlayer,
    "was",
    beforePlayer,
  );

  const beforeAdmin = await countPendingCreditRequests("ADMIN");
  const createdAdmin = await createCreditRequest(aid, 88, "verify admin request");
  const adminList = await listCreditRequests("ADMIN", "PENDING");
  const afterAdmin = await countPendingCreditRequests("ADMIN");
  console.log("ADMIN_CREATE", createdAdmin.status, createdAdmin.amount);
  console.log(
    "SA_SEES_ADMIN",
    adminList.some((row) => row.id === createdAdmin.id),
    "count",
    afterAdmin,
    "was",
    beforeAdmin,
  );

  let blocked = false;
  try {
    await reviewCreditRequest(aid, "ADMIN", createdAdmin.id, "approve", "");
  } catch (error) {
    blocked = true;
    console.log("ADMIN_BLOCKED_ADMIN_REQUEST", error instanceof Error ? error.message : error);
  }
  if (!blocked) {
    throw new Error("ADMIN should not approve ADMIN requests");
  }

  const approvedPlayer = await reviewCreditRequest(aid, "ADMIN", createdPlayer.id, "approve", "");
  console.log("PLAYER_APPROVED", approvedPlayer.request.status, "balance", approvedPlayer.balance);

  const approvedAdmin = await reviewCreditRequest(sid, "SUPER_ADMIN", createdAdmin.id, "approve", "");
  console.log("ADMIN_APPROVED", approvedAdmin.request.status, "balance", approvedAdmin.balance);

  console.log(
    "PENDING_AFTER",
    await countPendingCreditRequests("PLAYER"),
    await countPendingCreditRequests("ADMIN"),
  );
  await pool.end();
}

main().catch(async (error) => {
  console.error(error);
  await pool.end();
  process.exit(1);
});
