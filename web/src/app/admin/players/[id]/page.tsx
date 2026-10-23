import { Suspense } from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { AdjustCreditsForm } from "@/components/forms";
import { Badge, Notice, PageTitle, Panel } from "@/components/shell";
import { Rows } from "@/components/rows";
import { credits, when } from "@/lib/format";
import { api, ApiError } from "@/server/api";
import { requireUser } from "@/server/session";
import {
  saveGameProfileAction,
  setPlayerModeAction,
  updatePlayerAction,
} from "@/server/actions";
import type { Activity, PlayerGameProfile, PlayerSummary, SpinRecord, Transaction } from "@/lib/types";

export default function PlayerDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ credits?: string }>;
}) {
  return (
    <Suspense fallback={<p className="text-muted">Loading player…</p>}>
      <Detail params={params} searchParams={searchParams} />
    </Suspense>
  );
}

async function Detail({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ credits?: string }>;
}) {
  const { id } = await params;
  const query = await searchParams;
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  let history: { user: PlayerSummary; transactions: Transaction[]; spins: SpinRecord[]; activity: Activity[] };
  try {
    history = await api("/api/admin/users/" + id + "/history", auth.token);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) {
      notFound();
    }
    throw error;
  }
  const profiles = await api<{ profiles: PlayerGameProfile[] }>(`/api/admin/users/${id}/game-profiles`, auth.token);
  const user = history.user;
  return (
    <>
      {query.credits ? <Notice>Credits updated.</Notice> : null}
      <PageTitle
        kicker="Player"
        title={user.displayName || user.username}
        detail={`${user.email} · level ${user.level ?? 1} · ${credits(user.balance)} credits`}
      />
      <div className="mb-4 flex gap-3 text-sm">
        <Link href="/admin/players">All players</Link>
        {auth.user.role === "SUPER_ADMIN" ? <Link href={`/admin/ledger/${user.id}`}>Ledger</Link> : null}
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <Panel title="Account">
          <form action={updatePlayerAction} className="grid gap-3">
            <input type="hidden" name="id" value={user.id} />
            <label className="grid gap-1 text-sm">
              Display name
              <input className="field" name="displayName" defaultValue={user.displayName ?? user.username} required />
            </label>
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" name="isActive" value="true" defaultChecked={user.isActive} />
              Active
            </label>
            <button className="btn" type="submit">
              Save account
            </button>
          </form>
        </Panel>
        <Panel title="Difficulty">
          <form action={setPlayerModeAction} className="grid gap-3">
            <input type="hidden" name="id" value={user.id} />
            <select className="field" name="gameMode" defaultValue={user.gameMode}>
              <option>EASY</option>
              <option>MEDIUM</option>
              <option>HARD</option>
            </select>
            <button className="btn" type="submit">
              Save mode
            </button>
          </form>
        </Panel>
        <Panel title="Move credits">
          <AdjustCreditsForm userId={user.id} />
        </Panel>
        <Panel title="Status">
          <p>
            <Badge tone={user.isActive ? "good" : "bad"}>{user.isActive ? "Active" : "Inactive"}</Badge>
          </p>
          <p className="mt-2 text-sm text-muted">Joined {when(user.createdAt)}</p>
        </Panel>
      </div>
      <div className="mt-4 grid gap-4">
        <Panel title="Plays">
          <Rows
            columns={["Game", "Bet", "Win", "When"]}
            rows={history.spins.map((spin) => [spin.gameName, credits(spin.betAmount), credits(spin.winAmount), when(spin.createdAt)])}
          />
        </Panel>
        <Panel title="Transactions">
          <Rows
            columns={["Type", "Amount", "Balance", "When"]}
            rows={history.transactions.map((row) => [row.transactionType, credits(row.amount), credits(row.balanceAfter), when(row.createdAt)])}
          />
        </Panel>
        <Panel title="Staff notes">
          <Rows
            columns={["Action", "By", "Amount", "When"]}
            rows={history.activity.map((row) => [row.action, row.adminUsername, row.amount === null ? "—" : credits(row.amount), when(row.createdAt)])}
          />
        </Panel>
        <Panel title="Game tuning">
          <div className="grid gap-2">
            {profiles.profiles.map((profile) => (
              <details key={profile.gameId} className="rounded-xl border border-line px-3 py-2">
                <summary className="cursor-pointer">
                  {profile.gameName} · {profile.assignedProfile}
                </summary>
                <form action={saveGameProfileAction} className="mt-3 grid gap-2">
                  <input type="hidden" name="id" value={user.id} />
                  <input type="hidden" name="gameId" value={profile.gameId} />
                  <select className="field" name="profile" defaultValue={profile.assignedProfile}>
                    <option>DEFAULT</option>
                    <option>EASY</option>
                    <option>MEDIUM</option>
                    <option>HARD</option>
                  </select>
                  {profile.parameterDefs.map((def) => (
                    <label key={def.key} className="grid gap-1 text-sm">
                      {def.label}
                      <input
                        className="field"
                        type="number"
                        name={`param:${def.key}`}
                        min={def.min}
                        max={def.max}
                        step={def.step}
                        defaultValue={profile.parameters[def.key] ?? def.defaultValue}
                      />
                    </label>
                  ))}
                  <button className="btn" type="submit">
                    Save tuning
                  </button>
                </form>
              </details>
            ))}
          </div>
        </Panel>
      </div>
    </>
  );
}
