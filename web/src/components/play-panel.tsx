"use client";

import { useEffect, useRef, useState } from "react";
import type { GameSummary, PlayReceipt } from "@/lib/types";
import { credits } from "@/lib/format";
import { spinAction } from "@/server/actions";
import type { RoundView, StageHandle, StagePhase, StageState } from "@/game/stage";

type ChoiceKind = "lane" | "coin" | "box" | "number";

function choiceKind(slug: string): ChoiceKind | null {
  if (slug === "dollar-rush") return "lane";
  if (slug === "coin-flip") return "coin";
  if (slug === "treasure-box") return "box";
  if (slug === "lucky-number") return "number";
  return null;
}

export function PlayPanel({ game, balance }: { game: GameSummary; balance: number }) {
  const kind = choiceKind(game.slug);
  const [creditsLeft, setCreditsLeft] = useState(balance);
  const [bet, setBet] = useState(game.minimumBet);
  const [choice, setChoice] = useState<string | number | null>(
    kind === "coin" ? "HEADS" : kind === "number" ? 1 : kind ? 0 : null,
  );
  const [error, setError] = useState("");
  const [phase, setPhase] = useState<StagePhase>("idle");
  const [round, setRound] = useState<RoundView | null>(null);
  const step = Math.max(1, Math.round(game.minimumBet));
  const clamped = Math.min(game.maximumBet, Math.max(game.minimumBet, bet || game.minimumBet));

  async function play() {
    setError("");
    if (kind === "number" && (typeof choice !== "number" || choice < 1 || choice > 10)) {
      setError("Choose a number from 1 to 10.");
      return;
    }
    setPhase("drawing");
    const result = await spinAction({ slug: game.slug, bet: clamped, choice });
    if (!result.ok) {
      setPhase(round ? "result" : "idle");
      setError(result.error);
      return;
    }
    setCreditsLeft(result.receipt.balance);
    setRound(toView(result.receipt));
    setPhase("result");
  }

  function nudge(next: number) {
    setBet(Math.min(game.maximumBet, Math.max(game.minimumBet, next)));
  }

  return (
    <section className="grid gap-4">
      <Stage gameName={game.name} slug={game.slug} phase={phase} round={round} />
      <div className="rounded-3xl border border-line bg-panel p-4">
        <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-xs tracking-[0.16em] text-gold uppercase">{game.category}</p>
            <p className="font-display text-2xl">{credits(creditsLeft)} credits</p>
          </div>
          <p className="text-sm text-muted">
            Bet {game.minimumBet}–{game.maximumBet}
            {round ? ` · last ${round.winAmount > 0 ? `win ${credits(round.winAmount)}` : "miss"}` : ""}
          </p>
        </div>
        <Choice kind={kind} value={choice} onChange={setChoice} />
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <button className="btn-ghost" type="button" onClick={() => nudge(game.minimumBet)} disabled={phase === "drawing"}>
            Min
          </button>
          <button className="btn-ghost" type="button" onClick={() => nudge(clamped - step)} disabled={phase === "drawing"}>
            −
          </button>
          <label className="grid gap-1 text-xs tracking-wide text-muted uppercase">
            Bet
            <input
              className="field w-28"
              type="number"
              min={game.minimumBet}
              max={game.maximumBet}
              step={step}
              value={clamped}
              onChange={(event) => nudge(Number(event.target.value))}
            />
          </label>
          <button className="btn-ghost" type="button" onClick={() => nudge(clamped + step)} disabled={phase === "drawing"}>
            +
          </button>
          <button className="btn-ghost" type="button" onClick={() => nudge(game.maximumBet)} disabled={phase === "drawing"}>
            Max
          </button>
          <button className="btn ml-auto px-6" type="button" onClick={() => void play()} disabled={phase === "drawing" || creditsLeft < clamped}>
            {phase === "drawing" ? "Drawing…" : "Play"}
          </button>
        </div>
        {error ? <p className="mt-3 text-sm text-bad">{error}</p> : null}
      </div>
    </section>
  );
}

function Choice({
  kind,
  value,
  onChange,
}: {
  kind: ChoiceKind | null;
  value: string | number | null;
  onChange: (value: string | number) => void;
}) {
  if (!kind) return null;
  if (kind === "lane") {
    return <Picks label="Choose a lane" options={["Left", "Center", "Right"]} value={Number(value)} onChange={onChange} />;
  }
  if (kind === "box") {
    return <Picks label="Choose a box" options={["Box 1", "Box 2", "Box 3", "Box 4"]} value={Number(value)} onChange={onChange} />;
  }
  if (kind === "coin") {
    return (
      <Picks
        label="Call the coin"
        options={["Heads", "Tails"]}
        value={value === "TAILS" ? 1 : 0}
        onChange={(index) => onChange(index === 0 ? "HEADS" : "TAILS")}
      />
    );
  }
  return (
    <fieldset>
      <legend className="mb-2 text-xs tracking-wide text-muted uppercase">Pick 1 to 10</legend>
      <div className="flex flex-wrap gap-2">
        {Array.from({ length: 10 }, (_, index) => index + 1).map((number) => (
          <button key={number} type="button" className={number === value ? "btn h-10 w-10" : "btn-ghost h-10 w-10"} onClick={() => onChange(number)}>
            {number}
          </button>
        ))}
      </div>
    </fieldset>
  );
}

function Picks({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: string[];
  value: number;
  onChange: (value: number) => void;
}) {
  return (
    <fieldset>
      <legend className="mb-2 text-xs tracking-wide text-muted uppercase">{label}</legend>
      <div className="flex flex-wrap gap-2">
        {options.map((option, index) => (
          <button key={option} type="button" className={index === value ? "btn" : "btn-ghost"} onClick={() => onChange(index)}>
            {option}
          </button>
        ))}
      </div>
    </fieldset>
  );
}

function Stage({
  gameName,
  slug,
  phase,
  round,
}: {
  gameName: string;
  slug: string;
  phase: StagePhase;
  round: RoundView | null;
}) {
  const host = useRef<HTMLDivElement>(null);
  const handle = useRef<StageHandle | null>(null);

  const view = useRef<StageState>({ phase, gameName, slug, round });

  useEffect(() => {
    const parent = host.current;
    if (!parent) return;
    let cancelled = false;
    void import("@/game/stage").then((mod) => {
      if (cancelled || !host.current) return;
      handle.current = mod.mountStage(host.current);
      handle.current.show(view.current);
    });
    return () => {
      cancelled = true;
      handle.current?.destroy();
      handle.current = null;
    };
  }, []);

  useEffect(() => {
    view.current = { phase, gameName, slug, round };
    handle.current?.show(view.current);
  }, [phase, gameName, slug, round]);

  return (
    <div className="overflow-hidden rounded-3xl border border-gold/40 bg-ink shadow-[0_24px_50px_rgb(0_0_0/0.35)]">
      <div ref={host} className="aspect-video w-full" />
    </div>
  );
}

function toView(receipt: PlayReceipt): RoundView {
  return {
    title: receipt.title,
    winAmount: receipt.winAmount,
    betAmount: receipt.betAmount,
    multiplier: receipt.multiplier,
    presentation: receipt.presentation,
  };
}
