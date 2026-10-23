import { Suspense } from "react";
import Link from "next/link";
import { CreatePlayerForm } from "@/components/forms";
import { Badge, Notice, PageTitle, Panel } from "@/components/shell";
import { Rows } from "@/components/rows";
import { credits, when } from "@/lib/format";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import type { PlayerSummary } from "@/lib/types";

export default function PlayersPage({ searchParams }: { searchParams: Promise<{ created?: string }> }) {
  return (
    <Suspense fallback={<p className="text-muted">Loading players…</p>}>
      <Players searchParams={searchParams} />
    </Suspense>
  );
}

async function Players({ searchParams }: { searchParams: Promise<{ created?: string }> }) {
  const query = await searchParams;
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const data = await api<{ users: PlayerSummary[]; totalPlayers: number; totalCredits: number }>("/api/admin/users", auth.token);
  return (
    <>
      {query.created ? <Notice>Player account created.</Notice> : null}
      <PageTitle kicker="Accounts" title="Players" detail={`${data.totalPlayers} players · ${credits(data.totalCredits)} credits in player wallets`} />
      <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_20rem]">
        <Panel title="Directory">
          <Rows
            columns={["Player", "Credits", "Mode", "Status", "Joined"]}
            rows={data.users.map((user) => [
              <Link key={user.id} href={`/admin/players/${user.id}`}>
                {user.displayName || user.username}
                <span className="block text-xs text-muted">{user.email}</span>
              </Link>,
              credits(user.balance),
              user.gameMode,
              <Badge key={`${user.id}-status`} tone={user.isActive ? "good" : "bad"}>
                {user.isActive ? "Active" : "Inactive"}
              </Badge>,
              when(user.createdAt),
            ])}
          />
        </Panel>
        <Panel title="New player">
          <CreatePlayerForm />
        </Panel>
      </div>
    </>
  );
}
