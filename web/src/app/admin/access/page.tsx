import { Suspense } from "react";
import { Badge, PageTitle, Panel } from "@/components/shell";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import { setGameAccessAction } from "@/server/actions";
import type { PlayerGameAccessSummary } from "@/lib/types";

export default function AccessPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  return (
    <Suspense fallback={<p className="text-muted">Loading access…</p>}>
      <Access searchParams={searchParams} />
    </Suspense>
  );
}

async function Access({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const { q } = await searchParams;
  const auth = await requireUser(["SUPER_ADMIN"]);
  const query = q?.trim() ?? "";
  let summary: PlayerGameAccessSummary | null = null;
  let error = "";
  if (query) {
    try {
      summary = await api<PlayerGameAccessSummary>(
        `/api/admin/game-access/search?q=${encodeURIComponent(query)}`,
        auth.token,
      );
    } catch (caught) {
      error = caught instanceof Error ? caught.message : "Search failed.";
    }
  }

  return (
    <>
      <PageTitle kicker="Super admin" title="Game access" detail="Search a player by username or email, then open or close individual games." />
      <form className="mb-4 flex flex-wrap gap-2" action="/admin/access">
        <input className="field max-w-sm" name="q" defaultValue={query} placeholder="Username or email" />
        <button className="btn" type="submit">
          Search
        </button>
      </form>
      {error ? <p className="mb-4 text-sm text-bad">{error}</p> : null}
      {summary ? (
        <Panel
          title={`${summary.player.username} · ${summary.enabledCount} open · ${summary.disabledCount} closed`}
          action={
            <div className="flex gap-2">
              <AccessAll playerId={summary.player.id} enabled />
              <AccessAll playerId={summary.player.id} enabled={false} />
            </div>
          }
        >
          <div className="grid gap-2">
            {summary.games.map((game) => (
              <div key={game.gameId} className="flex flex-wrap items-center justify-between gap-3 border-t border-line py-2">
                <div>
                  <p>{game.name}</p>
                  <p className="text-xs text-muted">
                    {game.category} · {game.globallyActive ? "Live in catalog" : "Hidden in catalog"}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <Badge tone={game.enabled ? "good" : "bad"}>{game.enabled ? "Open" : "Closed"}</Badge>
                  <form action={setGameAccessAction}>
                    <input type="hidden" name="playerId" value={summary.player.id} />
                    <input type="hidden" name="gameId" value={game.gameId} />
                    <input type="hidden" name="enabled" value={String(!game.enabled)} />
                    <button className="btn-ghost" type="submit">
                      {game.enabled ? "Close" : "Open"}
                    </button>
                  </form>
                </div>
              </div>
            ))}
          </div>
        </Panel>
      ) : null}
    </>
  );
}

function AccessAll({ playerId, enabled }: { playerId: string; enabled: boolean }) {
  return (
    <form action={setGameAccessAction}>
      <input type="hidden" name="playerId" value={playerId} />
      <input type="hidden" name="enabled" value={String(enabled)} />
      <button className="btn-ghost" type="submit">
        {enabled ? "Open all" : "Close all"}
      </button>
    </form>
  );
}
