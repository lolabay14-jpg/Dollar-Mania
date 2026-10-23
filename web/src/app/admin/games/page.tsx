import { Suspense } from "react";
import { Badge, PageTitle, Panel } from "@/components/shell";
import { credits } from "@/lib/format";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import { setGameActiveAction, setPlatformModeAction } from "@/server/actions";
import type { GameMode, GameSummary } from "@/lib/types";

export default function GamesAdminPage() {
  return (
    <Suspense fallback={<p className="text-muted">Loading games…</p>}>
      <Games />
    </Suspense>
  );
}

async function Games() {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const settings = await api<{ gameMode: GameMode; games: GameSummary[] }>("/api/admin/settings", auth.token);
  return (
    <>
      <PageTitle kicker="Floor" title="Games" detail="Turn games on for everyone, and set the house difficulty." />
      <Panel title="House mode" className="mb-4">
        <form action={setPlatformModeAction} className="flex flex-wrap items-end gap-3">
          <select className="field max-w-48" name="gameMode" defaultValue={settings.gameMode}>
            <option>EASY</option>
            <option>MEDIUM</option>
            <option>HARD</option>
          </select>
          <button className="btn" type="submit">
            Save mode
          </button>
        </form>
      </Panel>
      <Panel title="Catalog">
        <div className="grid gap-3">
          {settings.games.map((game) => (
            <article key={game.id} className="flex flex-wrap items-center justify-between gap-3 border-t border-line py-3">
              <div>
                <h3 className="font-display text-lg">{game.name}</h3>
                <p className="text-sm text-muted">
                  {game.category} · {game.difficulty} · {game.minimumBet}–{game.maximumBet} · {credits(game.spins ?? 0)} plays
                </p>
              </div>
              <div className="flex items-center gap-3">
                <Badge tone={game.isActive ? "good" : "bad"}>{game.isActive ? "Live" : "Hidden"}</Badge>
                <form action={setGameActiveAction}>
                  <input type="hidden" name="id" value={game.id} />
                  <input type="hidden" name="isActive" value={String(!game.isActive)} />
                  <button className="btn-ghost" type="submit">
                    {game.isActive ? "Hide" : "Show"}
                  </button>
                </form>
              </div>
            </article>
          ))}
        </div>
      </Panel>
    </>
  );
}
