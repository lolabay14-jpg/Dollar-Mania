import { Suspense } from "react";
import Link from "next/link";
import { PageTitle, Panel, Stat } from "@/components/shell";
import { Rows } from "@/components/rows";
import { credits, titleCase, when } from "@/lib/format";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import type { AdminOverview } from "@/lib/types";

export default function AdminHome() {
  return (
    <Suspense fallback={<p className="text-muted">Loading overview…</p>}>
      <Overview />
    </Suspense>
  );
}

async function Overview() {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const data = await api<AdminOverview>("/api/admin/overview", auth.token);
  const pending = auth.user.role === "SUPER_ADMIN" ? data.pendingAdminRequests : data.pendingPlayerRequests;
  return (
    <>
      <PageTitle kicker={titleCase(auth.user.role)} title="Overview" detail="Virtual credits only. Payouts stay on the API." />
      <div className="mb-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Stat label="Your balance" value={credits(data.myBalance)} />
        <Stat label="Players" value={`${data.activePlayers}/${data.totalPlayers}`} />
        <Stat label="Player credits" value={credits(data.playerCredits)} />
        <Stat label="Pending requests" value={String(pending)} />
        <Stat label="Active games" value={`${data.activeGames}/${data.totalGames}`} />
        <Stat label="Plays" value={credits(data.totalSpins)} />
        <Stat label="Sessions" value={credits(data.totalSessions)} />
        {auth.user.role === "SUPER_ADMIN" ? <Stat label="Admin credits" value={credits(data.allocatedCredits)} /> : null}
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <Panel title="Recent plays" action={<Link href="/admin/activity">Activity</Link>}>
          <Rows
            columns={["Player", "Game", "Bet", "Win"]}
            rows={data.recentPlays.map((play) => [play.username, play.gameName, credits(play.betAmount), credits(play.winAmount)])}
          />
        </Panel>
        <Panel title="Recent credits" action={<Link href="/admin/requests">Requests</Link>}>
          <Rows
            columns={["Who", "Amount", "When"]}
            rows={data.recentTransactions.map((row) => [row.username, credits(row.amount), when(row.createdAt)])}
          />
        </Panel>
      </div>
    </>
  );
}
