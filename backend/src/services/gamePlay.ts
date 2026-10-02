import { randomInt } from "crypto";
import { AppError } from "../errors";
import { playRound, rulesForSlug, type SymbolId } from "./slotRules";

export type PlayRound = {
  multiplier: number;
  title: string;
  presentation: Record<string, unknown>;
};

const SYMBOLS: SymbolId[] = ["COIN", "DOLLAR", "STAR", "DIAMOND", "SEVEN", "BONUS"];

const FIVE_REEL_WEIGHTS = [34, 24, 16, 12, 8, 6];

const FIVE_REEL_PAY: Record<SymbolId, number[]> = {
  COIN: [0, 0, 2, 6, 20],
  DOLLAR: [0, 0, 3, 8, 30],
  STAR: [0, 0, 4, 12, 40],
  DIAMOND: [0, 0, 6, 16, 60],
  SEVEN: [0, 0, 8, 22, 80],
  BONUS: [0, 0, 12, 30, 100],
};

const SLUG_ALIASES: Record<string, string> = {
  lucky_dollar: "lucky-dollar",
  golden_fortune: "golden-fortune",
  dollar_rush: "dollar-rush",
};

export function resolveRound(slug: string, choice?: unknown): PlayRound {
  const game = SLUG_ALIASES[slug] ?? slug;
  switch (game) {
    case "lucky-dollar":
      return luckyDollar();
    case "golden-fortune":
      return goldenFortune();
    case "dollar-rush":
      return dollarRush(choice);
    case "scratch-mania":
      return scratchMania();
    case "lucky-spin":
      return spinWheel("wheel", [0, 0, 0, 1, 0, 2, 0, 0, 5, 0, 1, 0], [18, 14, 14, 10, 12, 8, 12, 10, 4, 12, 8, 12]);
    case "coin-flip":
      return coinFlip(choice);
    case "treasure-box":
      return treasureBox(choice);
    case "cash-match":
      return cashMatch();
    case "diamond-drop":
      return diamondDrop();
    case "bonus-burst":
      return bonusBurst();
    case "jackpot-wheel":
      return spinWheel(
        "jackpot",
        [0, 1, 0, 2, 0, 5, 0, 1, 0, 10, 0, 50],
        [20, 8, 16, 6, 16, 3, 14, 8, 12, 2, 14, 1],
      );
    default:
      throw new AppError(400, "This game is not ready yet.");
  }
}

function luckyDollar(): PlayRound {
  const round = playRound(rulesForSlug("lucky-dollar"));
  return {
    multiplier: round.multiplier,
    title: round.title,
    presentation: {
      kind: "reels",
      grid: round.grid,
      payline: round.payline,
      highlights: round.highlights,
    },
  };
}

function goldenFortune(): PlayRound {
  const grid: SymbolId[][] = [];
  for (let reel = 0; reel < 5; reel += 1) {
    grid.push([pickWeighted(SYMBOLS, FIVE_REEL_WEIGHTS), pickWeighted(SYMBOLS, FIVE_REEL_WEIGHTS), pickWeighted(SYMBOLS, FIVE_REEL_WEIGHTS)]);
  }
  const payline = grid.map((column) => column[1]);
  const counts = new Map<SymbolId, number>();
  for (const symbol of payline) {
    counts.set(symbol, (counts.get(symbol) ?? 0) + 1);
  }
  let bestSymbol: SymbolId = "COIN";
  let bestCount = 0;
  let multiplier = 0;
  for (const [symbol, count] of counts) {
    const payout = FIVE_REEL_PAY[symbol][count - 1] ?? 0;
    if (payout > multiplier) {
      multiplier = payout;
      bestSymbol = symbol;
      bestCount = count;
    }
  }
  const highlights = multiplier > 0 ? payline.map((symbol, index) => (symbol === bestSymbol ? index : -1)).filter((index) => index >= 0) : [];
  return {
    multiplier,
    title: multiplier > 0 ? `${bestCount} ${bestSymbol}` : "No win",
    presentation: { kind: "reels", grid, payline, highlights },
  };
}

function dollarRush(choice: unknown): PlayRound {
  const lane = wholeNumber(choice);
  if (lane === null || lane < 0 || lane > 2) {
    throw new AppError(400, "Choose a lane first.");
  }
  const hot = randomInt(100) < 30;
  const winningLane = hot ? randomInt(3) : -1;
  const hit = lane === winningLane;
  return {
    multiplier: hit ? 8 : 0,
    title: hit ? "Lane hit" : "Missed the rush",
    presentation: { kind: "rush", lane, winningLane, hit },
  };
}

function scratchMania(): PlayRound {
  const weights = [40, 28, 16, 8, 5, 3];
  const cells = Array.from({ length: 6 }, () => pickWeighted(SYMBOLS, weights));
  const counts = new Map<string, number>();
  for (const cell of cells) {
    counts.set(cell, (counts.get(cell) ?? 0) + 1);
  }
  let matches = 0;
  for (const count of counts.values()) {
    matches = Math.max(matches, count);
  }
  const table = [0, 0, 0, 2, 5, 12, 25];
  const multiplier = table[matches] ?? 0;
  return {
    multiplier,
    title: multiplier > 0 ? `${matches} matched` : "No match",
    presentation: { kind: "scratch", cells, matches },
  };
}

function spinWheel(kind: "wheel" | "jackpot", segments: number[], weights: number[]): PlayRound {
  const index = weightedIndex(weights);
  const multiplier = segments[index] ?? 0;
  const title = multiplier <= 0 ? "No prize" : multiplier >= 50 ? "Jackpot" : `${multiplier}x segment`;
  return {
    multiplier,
    title,
    presentation: { kind, segments, index },
  };
}

function coinFlip(choice: unknown): PlayRound {
  const call = String(choice ?? "").toUpperCase();
  if (call !== "HEADS" && call !== "TAILS") {
    throw new AppError(400, "Call heads or tails first.");
  }
  const won = randomInt(100) < 47;
  const face = won ? call : call === "HEADS" ? "TAILS" : "HEADS";
  return {
    multiplier: won ? 1.9 : 0,
    title: won ? `${face} wins` : `${face}`,
    presentation: { kind: "coin", call, face, won },
  };
}

function treasureBox(choice: unknown): PlayRound {
  const index = wholeNumber(choice);
  if (index === null || index < 0 || index > 3) {
    throw new AppError(400, "Choose a box first.");
  }
  const table = [0, 1, 2, 4, 8, 12];
  const weights = [60, 22, 10, 5, 2, 1];
  const rewards = [0, 1, 2, 3].map(() => pickWeighted(table, weights));
  rewards[index] = pickWeighted(table, weights);
  return {
    multiplier: rewards[index],
    title: rewards[index] > 0 ? `Box ${index + 1}` : "Empty box",
    presentation: { kind: "boxes", rewards, index },
  };
}

function cashMatch(): PlayRound {
  const tiers = [
    { pairs: 0, multiplier: 0, weight: 55 },
    { pairs: 1, multiplier: 1, weight: 30 },
    { pairs: 2, multiplier: 3, weight: 12 },
    { pairs: 3, multiplier: 8, weight: 3 },
  ];
  const tier = tiers[weightedIndex(tiers.map((entry) => entry.weight))];
  const glyphs = ["$", "*", "#", "7", "O", "+", "=", "@"];
  const order = shuffle([0, 1, 2, 3, 4, 5]);
  const cards = Array.from({ length: 6 }, () => "");
  const matched: number[] = [];
  let glyph = 0;
  let cursor = 0;
  for (let pair = 0; pair < tier.pairs; pair += 1) {
    const left = order[cursor];
    const right = order[cursor + 1];
    cursor += 2;
    cards[left] = glyphs[glyph];
    cards[right] = glyphs[glyph];
    glyph += 1;
    matched.push(left, right);
  }
  while (cursor < order.length) {
    cards[order[cursor]] = glyphs[glyph];
    glyph += 1;
    cursor += 1;
  }
  return {
    multiplier: tier.multiplier,
    title: tier.pairs > 0 ? `${tier.pairs} match${tier.pairs === 1 ? "" : "es"}` : "No match",
    presentation: { kind: "match", cards, matched },
  };
}

function diamondDrop(): PlayRound {
  const combos = [0, 1, 2, 3, 4, 5];
  const weights = [50, 28, 14, 5, 2, 1];
  const payouts = [0, 1, 2, 4, 6, 10];
  const combo = combos[weightedIndex(weights)];
  const gems = ["RUBY", "GOLD", "JADE", "BLUE"];
  const lead = gems[randomInt(gems.length)];
  const sequence: string[] = [];
  for (let index = 0; index < 6; index += 1) {
    if (index < combo) {
      sequence.push(lead);
    } else {
      const other = gems.filter((gem) => gem !== lead);
      sequence.push(other[randomInt(other.length)]);
    }
  }
  return {
    multiplier: payouts[combo],
    title: combo > 1 ? `${combo} in a row` : combo === 1 ? "Single gem" : "No match",
    presentation: { kind: "drop", gems: sequence, combo },
  };
}

function bonusBurst(): PlayRound {
  const counts = [0, 1, 2, 3, 4, 5];
  const weights = [40, 28, 16, 9, 5, 2];
  const payouts = [0, 0.5, 1, 2, 4, 8];
  const count = counts[weightedIndex(weights)];
  return {
    multiplier: payouts[count],
    title: count > 0 ? `${count} collected` : "Burst missed",
    presentation: { kind: "burst", count, seconds: 6 },
  };
}

function pickWeighted<T>(values: T[], weights: number[]): T {
  return values[weightedIndex(weights)];
}

function weightedIndex(weights: number[]): number {
  const total = weights.reduce((sum, weight) => sum + weight, 0);
  let roll = randomInt(total);
  for (let index = 0; index < weights.length; index += 1) {
    roll -= weights[index];
    if (roll < 0) {
      return index;
    }
  }
  return weights.length - 1;
}

function wholeNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value)) {
    return value;
  }
  if (typeof value === "string" && /^[0-9]+$/.test(value)) {
    return Number(value);
  }
  return null;
}

function shuffle(values: number[]): number[] {
  const copy = [...values];
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const swap = randomInt(index + 1);
    const current = copy[index];
    copy[index] = copy[swap];
    copy[swap] = current;
  }
  return copy;
}
