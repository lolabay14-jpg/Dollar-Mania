"use client";

import { useEffect, useState } from "react";
import type { GameSummary, PlayReceipt } from "@/lib/types";
import { credits } from "@/lib/format";
import { spinAction } from "@/server/actions";
import type { RoundView } from "@/game/stage";

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
  const [pending, setPending] = useState(false);
  const [round, setRound] = useState<RoundView | null>(null);

  const step = Math.max(1, game.minimumBet);
  const clamped = Math.min(game.maximumBet, Math.max(game.minimumBet, bet));

  async function play() {
    setError("");
    if (kind === "number" && (typeof choice !== "number" || choice < 1 || choice > 10)) {
      setError("Choose a number from 1 to 10.");
      return;
    }
    if (kind === "lane" && (typeof choice !== "number" || choice < 0 || choice > 2)) {
      setError("Choose a lane.");
      return;
    }
    if (kind === "box" && (typeof choice !== "number" || choice < 0 || choice > 3)) {
      setError("Choose a box.");
      return;
    }
    setPending(true);
    const result = await spinAction({ slug: game.slug, bet: clamped, choice });
    setPending(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setCreditsLeft(result.receipt.balance);
    setRound(toView(result.receipt));
  }

  return (
    <div className="grid gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <label className="grid gap-1 text-sm">
          Bet
          <input
            className="field w-32"
            type="number"
            min={game.minimumBet}
            max={game.maximumBet}
            step={step}
            value={clamped}
            onChange={(event) => setBet(Number(event.target.value))}
          />
        </label>
        <Choice kind={kind} value={choice} onChange={setChoice} />
        <button className="btn" type="button" onClick={() => void play()} disabled={pending || creditsLeft < clamped}>
          {pending ? "Asking the server…" : "Play"}
        </button>
        <p className="text-sm text-muted">Balance {credits(creditsLeft)}</p>
      </div>
      {error ? <p className="text-sm text-bad">{error}</p> : null}
      <Stage round={round} pending={pending} />
    </div>
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
  if (kind === "lane") {
    return <Picks label="Lane" options={["Left", "Middle", "Right"]} value={Number(value)} onChange={onChange} />;
  }
  if (kind === "box") {
    return <Picks label="Box" options={["1", "2", "3", "4"]} value={Number(value)} onChange={onChange} />;
  }
  if (kind === "coin") {
    return (
      <label className="grid gap-1 text-sm">
        Call
        <select className="field" value={String(value)} onChange={(event) => onChange(event.target.value)}>
          <option value="HEADS">Heads</option>
          <option value="TAILS">Tails</option>
        </select>
      </label>
    );
  }
  if (kind === "number") {
    return (
      <label className="grid gap-1 text-sm">
        Number
        <input
          className="field w-24"
          type="number"
          min={1}
          max={10}
          value={Number(value) || 1}
          onChange={(event) => onChange(Number(event.target.value))}
        />
      </label>
    );
  }
  return null;
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
    <fieldset className="grid gap-1 text-sm">
      <legend>{label}</legend>
      <div className="flex gap-2">
        {options.map((option, index) => (
          <button
            key={option}
            type="button"
            className={index === value ? "btn" : "btn-ghost"}
            onClick={() => onChange(index)}
          >
            {option}
          </button>
        ))}
      </div>
    </fieldset>
  );
}

function Stage({ round, pending }: { round: RoundView | null; pending: boolean }) {
  const [host, setHost] = useState<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!host) {
      return;
    }
    let destroy = () => {};
    let cancelled = false;
    void import("@/game/stage").then((mod) => {
      if (cancelled) {
        return;
      }
      destroy = mod.mountStage(host, round);
    });
    return () => {
      cancelled = true;
      destroy();
    };
  }, [host, round]);

  return (
    <div className="overflow-hidden rounded-2xl border border-line bg-ink">
      <div ref={setHost} className="h-[28rem] w-full" />
      {pending ? <p className="px-4 py-2 text-sm text-muted">The server is deciding this round.</p> : null}
    </div>
  );
}

function toView(receipt: PlayReceipt): RoundView {
  return {
    title: receipt.title,
    winAmount: receipt.winAmount,
    betAmount: receipt.betAmount,
    presentation: receipt.presentation,
  };
}
