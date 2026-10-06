import { randomInt } from "crypto";
import { AppError } from "../errors";
import { clampParameter } from "./gameParameters";
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

export type RoundParameters = Record<string, number>;

export function resolveRound(
  slug: string,
  choice?: unknown,
  difficulty = "MEDIUM",
  parameters: RoundParameters = {},
): PlayRound {
  const round = resolveBase(slug, choice, parameters);
  const tuned = applyDifficulty(round, difficulty, () => resolveBase(slug, choice, parameters));
  return alignTargets(applyRewardScale(slug, tuned, parameters));
}

function alignTargets(round: PlayRound): PlayRound {
  if (round.presentation.kind === "targets") {
    const targets = buildTargets(round.multiplier);
    const multiplier = targets.reduce((sum, target) => sum + target.points, 0);
    return {
      ...round,
      multiplier,
      title: multiplier > 0 ? "Targets cleared" : "No hit",
      presentation: { ...round.presentation, targets },
    };
  }
  if (round.presentation.kind === "flight") {
    const coins = buildCoins(round.multiplier);
    const multiplier = coins.reduce((sum, coin) => sum + coin.points, 0);
    return {
      ...round,
      multiplier,
      title: multiplier > 0 ? "Coins collected" : "Empty sky",
      presentation: { ...round.presentation, coins },
    };
  }
  if (round.presentation.kind === "bottles") {
    const bottles = buildBottles(round.multiplier);
    const multiplier = bottles.reduce((sum, bottle) => sum + bottle.points, 0);
    return {
      ...round,
      multiplier,
      title: multiplier > 0 ? "Bottles cleared" : "No break",
      presentation: { ...round.presentation, bottles },
    };
  }
  return round;
}

function resolveBase(slug: string, choice: unknown, parameters: RoundParameters): PlayRound {
  const game = SLUG_ALIASES[slug] ?? slug;
  switch (game) {
    case "lucky-dollar":
      return withLossReroll(slug, "lineBoost", parameters, luckyDollar);
    case "golden-fortune":
      return withLossReroll(slug, "lineBoost", parameters, goldenFortune);
    case "dollar-rush":
      return dollarRush(choice, parameters);
    case "scratch-mania":
      return withLossReroll(slug, "matchBoost", parameters, scratchMania);
    case "lucky-spin":
      return spinWheel(slug, "wheel", [0, 0, 0, 1, 0, 2, 0, 0, 5, 0, 1, 0], [18, 14, 14, 10, 12, 8, 12, 10, 4, 12, 8, 12], parameters);
    case "coin-flip":
      return coinFlip(choice, parameters);
    case "treasure-box":
      return treasureBox(choice, parameters);
    case "mystery-box":
      return mysteryBox(parameters);
    case "cash-match":
      return cashMatch(parameters);
    case "diamond-drop":
      return diamondDrop(parameters);
    case "bonus-burst":
      return bonusBurst(parameters);
    case "jackpot-wheel":
      return spinWheel(
        slug,
        "jackpot",
        [0, 1, 0, 2, 0, 5, 0, 1, 0, 10, 0, 50],
        [20, 8, 16, 6, 16, 3, 14, 8, 12, 2, 14, 1],
        parameters,
      );
    case "diamond-spin":
      return labeledWheel(
        slug,
        "diamond",
        [0, 2, 0, 4, 1, 8, 0, 3, 12, 2],
        [16, 12, 14, 8, 12, 4, 14, 10, 2, 8],
        ["ruby", "sapphire", "emerald", "diamond", "amethyst", "crystal", "gold", "jade", "seven", "star"],
        parameters,
      );
    case "fruit-spin":
      return labeledWheel(
        slug,
        "fruit",
        [0, 1, 0, 2, 1, 4, 2, 0, 8, 3],
        [14, 12, 14, 10, 12, 8, 8, 12, 3, 7],
        ["cherry", "lemon", "orange", "melon", "grapes", "berry", "diamond", "star", "seven", "coin"],
        parameters,
      );
    case "lucky-wheel":
      return labeledWheel(
        slug,
        "lucky",
        [0, 2, 0, 5, 1, 0, 10, 3, 0, 20],
        [16, 10, 14, 6, 12, 14, 3, 8, 14, 2],
        ["coin", "star", "coin", "diamond", "coin", "star", "seven", "coin", "star", "diamond"],
        parameters,
      );
    case "prize-spinner":
      return labeledWheel(
        slug,
        "spinner",
        [0, 1, 3, 0, 2, 8, 0, 4],
        [18, 14, 8, 16, 12, 3, 16, 6],
        ["coin", "star", "diamond", "coin", "seven", "bonus", "star", "dollar"],
        parameters,
      );
    case "fishing":
      return fishing();
    case "target-blast":
      return targetBlast();
    case "aeroplane-rush":
      return aeroplane();
    case "bottle-blast":
      return bottleBlast();
    case "dice":
      return dice();
    case "lucky-number":
      return luckyNumber(choice);
    case "higher-card":
      return higherCard();
    default:
      throw new AppError(400, "This game is not ready yet.");
  }
}

function applyRewardScale(slug: string, round: PlayRound, parameters: RoundParameters): PlayRound {
  const scale = clampParameter(slug, "rewardScale", parameters.rewardScale);
  if (round.multiplier === 0 || Math.abs(scale - 1) < 0.0001) {
    return round;
  }
  return {
    ...round,
    multiplier: Math.round(round.multiplier * scale * 100) / 100,
  };
}

function withLossReroll(
  slug: string,
  key: string,
  parameters: RoundParameters,
  build: () => PlayRound,
): PlayRound {
  const round = build();
  const chance = clampParameter(slug, key, parameters[key]);
  if (round.multiplier === 0 && chance > 0 && randomInt(100) < chance) {
    return build();
  }
  return round;
}

function applyDifficulty(round: PlayRound, difficulty: string, reroll: () => PlayRound): PlayRound {
  const level = difficulty.toUpperCase();
  if (level === "EASY" && round.multiplier === 0 && randomInt(100) < 30) {
    return reroll();
  }
  if (level === "HARD" && round.multiplier > 0 && round.multiplier < 5 && randomInt(100) < 45) {
    return reroll();
  }
  if (level === "HARD" && round.multiplier >= 8) {
    return {
      ...round,
      multiplier: Math.round(round.multiplier * 1.5 * 100) / 100,
      title: round.title,
    };
  }
  if (level === "MEDIUM" && round.multiplier >= 10) {
    return {
      ...round,
      multiplier: Math.round(round.multiplier * 1.15 * 100) / 100,
      title: round.title,
    };
  }
  return round;
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

function dollarRush(choice: unknown, parameters: RoundParameters): PlayRound {
  const lane = wholeNumber(choice);
  if (lane === null || lane < 0 || lane > 2) {
    throw new AppError(400, "Choose a lane first.");
  }
  const hot = randomInt(100) < clampParameter("dollar-rush", "hitChance", parameters.hitChance);
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

function labeledWheel(
  slug: string,
  kind: "fruit" | "lucky" | "spinner" | "diamond",
  segments: number[],
  weights: number[],
  symbols: string[],
  parameters: RoundParameters,
): PlayRound {
  const round = spinWheel(slug, kind, segments, weights, parameters);
  return {
    ...round,
    presentation: { ...round.presentation, symbols },
  };
}

function dice(): PlayRound {
  const first = randomInt(6) + 1;
  const second = randomInt(6) + 1;
  const total = first + second;
  const doubles = first === second;
  let multiplier = 0;
  if (total === 7) {
    multiplier = 2;
  } else if (doubles && (total === 2 || total === 12)) {
    multiplier = 8;
  } else if (doubles) {
    multiplier = 3;
  }
  return {
    multiplier,
    title: `${first} and ${second}`,
    presentation: { kind: "dice", dice: [first, second], total },
  };
}

function luckyNumber(choice: unknown): PlayRound {
  const pick = wholeNumber(choice);
  if (pick === null || pick < 1 || pick > 10) {
    throw new AppError(400, "Choose a number from 1 to 10.");
  }
  const draw = randomInt(10) + 1;
  const gap = Math.abs(draw - pick);
  const multiplier = gap === 0 ? 6 : gap === 1 ? 1 : 0;
  return {
    multiplier,
    title: gap === 0 ? `Number ${draw}` : `Drew ${draw}`,
    presentation: { kind: "number", pick, draw },
  };
}

function fishing(): PlayRound {
  const table = [
    { id: "none", name: "No catch", rarity: "Miss", multiplier: 0, weight: 28 },
    { id: "small", name: "Small Fish", rarity: "Common", multiplier: 1, weight: 32 },
    { id: "blue", name: "Blue Fish", rarity: "Uncommon", multiplier: 2, weight: 24 },
    { id: "golden", name: "Golden Fish", rarity: "Rare", multiplier: 5, weight: 12 },
    { id: "legend", name: "Legendary Fish", rarity: "Special", multiplier: 12, weight: 4 },
  ];
  const fish = table[weightedIndex(table.map((entry) => entry.weight))];
  return {
    multiplier: fish.multiplier,
    title: fish.multiplier > 0 ? fish.name : "The line came back empty",
    presentation: {
      kind: "fishing",
      fish: fish.id,
      name: fish.name,
      rarity: fish.rarity,
      duration: 14,
    },
  };
}

function targetBlast(): PlayRound {
  const tiers = [
    { multiplier: 0, weight: 42 },
    { multiplier: 1, weight: 26 },
    { multiplier: 2, weight: 16 },
    { multiplier: 3, weight: 8 },
    { multiplier: 5, weight: 5 },
    { multiplier: 8, weight: 2 },
    { multiplier: 12, weight: 1 },
  ];
  const tier = tiers[weightedIndex(tiers.map((entry) => entry.weight))];
  const targets = buildTargets(tier.multiplier);
  const multiplier = targets.reduce((sum, target) => sum + target.points, 0);
  return {
    multiplier,
    title: multiplier > 0 ? "Targets cleared" : "No hit",
    presentation: { kind: "targets", duration: 12, targets },
  };
}

function aeroplane(): PlayRound {
  const tiers = [
    { multiplier: 0, weight: 40 },
    { multiplier: 1, weight: 26 },
    { multiplier: 2, weight: 16 },
    { multiplier: 3, weight: 9 },
    { multiplier: 5, weight: 6 },
    { multiplier: 8, weight: 2 },
    { multiplier: 12, weight: 1 },
  ];
  const tier = tiers[weightedIndex(tiers.map((entry) => entry.weight))];
  const coins = buildCoins(tier.multiplier);
  const multiplier = coins.reduce((sum, coin) => sum + coin.points, 0);
  const obstacles = [0, 1, 2, 1].map((lane, index) => ({ lane, delay: Math.round((1.2 + index * 1.7) * 100) / 100 }));
  return {
    multiplier,
    title: multiplier > 0 ? "Coins collected" : "Empty sky",
    presentation: { kind: "flight", duration: 12, coins, obstacles },
  };
}

function buildCoins(multiplier: number): Array<{ lane: number; points: number; delay: number }> {
  const total = Math.max(0, Math.round(multiplier));
  if (total <= 0) {
    return [{ lane: 1, points: 0, delay: 0.8 }];
  }
  const coins: Array<{ lane: number; points: number; delay: number }> = [];
  let remaining = total;
  let delay = 0.45;
  let index = 0;
  while (remaining > 0 && coins.length < 6) {
    const points = Math.min(remaining >= 3 && index === 2 ? 2 : 1, remaining);
    coins.push({ lane: index % 3, points, delay: Math.round(delay * 100) / 100 });
    remaining -= points;
    delay += 1.35;
    index += 1;
  }
  return coins;
}

function bottleBlast(): PlayRound {
  const tiers = [
    { multiplier: 0, weight: 40 },
    { multiplier: 1, weight: 26 },
    { multiplier: 2, weight: 16 },
    { multiplier: 3, weight: 9 },
    { multiplier: 5, weight: 6 },
    { multiplier: 8, weight: 2 },
    { multiplier: 12, weight: 1 },
  ];
  const tier = tiers[weightedIndex(tiers.map((entry) => entry.weight))];
  const bottles = buildBottles(tier.multiplier);
  const multiplier = bottles.reduce((sum, bottle) => sum + bottle.points, 0);
  return {
    multiplier,
    title: multiplier > 0 ? "Bottles cleared" : "No break",
    presentation: { kind: "bottles", duration: 12, bottles },
  };
}

function buildBottles(
  multiplier: number,
): Array<{ type: string; points: number; delay: number; bonus: boolean }> {
  const total = Math.max(0, Math.round(multiplier));
  if (total <= 0) {
    return [
      { type: "normal", points: 0, delay: 0.3, bonus: false },
      { type: "fast", points: 0, delay: 1.5, bonus: false },
    ];
  }
  const bottles: Array<{ type: string; points: number; delay: number; bonus: boolean }> = [];
  let remaining = total;
  let delay = 0.3;
  let index = 0;
  const types = ["normal", "fast", "golden", "bonus"];
  while (remaining > 0 && bottles.length < 6) {
    const points = Math.min(remaining >= 3 && index === 2 ? 2 : 1, remaining);
    const bonus = points > 1;
    const type = bonus ? "golden" : types[index % types.length];
    bottles.push({ type, points, delay: Math.round(delay * 100) / 100, bonus });
    remaining -= points;
    delay += 1.15;
    index += 1;
  }
  return bottles;
}

function buildTargets(multiplier: number): Array<{ size: string; points: number; delay: number; bonus: boolean }> {
  const total = Math.max(0, Math.round(multiplier));
  if (total <= 0) {
    return [
      { size: "small", points: 0, delay: 0.3, bonus: false },
      { size: "medium", points: 0, delay: 1.4, bonus: false },
      { size: "large", points: 0, delay: 2.6, bonus: false },
    ];
  }
  const targets: Array<{ size: string; points: number; delay: number; bonus: boolean }> = [];
  let remaining = total;
  let delay = 0.35;
  let index = 0;
  while (remaining > 0 && targets.length < 6) {
    let points = 1;
    if (remaining >= 4 && index === 1) {
      points = 2;
    }
    points = Math.min(points, remaining);
    const bonus = points > 1;
    const size = bonus ? "bonus" : index % 3 === 0 ? "small" : index % 3 === 1 ? "medium" : "large";
    targets.push({ size, points, delay: Math.round(delay * 100) / 100, bonus });
    remaining -= points;
    delay += 1.2;
    index += 1;
  }
  return targets;
}

function mysteryBox(parameters: RoundParameters): PlayRound {
  const table = [0, 1, 2, 4, 8];
  const weights = [36, 28, 18, 12, 6];
  const bias = clampParameter("mystery-box", "prizeBias", parameters.prizeBias);
  const tuned = weights.map((weight, index) => (table[index] > 0 ? weight + bias : weight));
  const multiplier = pickWeighted(table, tuned);
  return {
    multiplier,
    title: multiplier > 0 ? "Box opened" : "Empty box",
    presentation: { kind: "mystery", prize: multiplier },
  };
}

function spinWheel(
  slug: string,
  kind: "wheel" | "jackpot" | "fruit" | "lucky" | "spinner" | "diamond",
  segments: number[],
  weights: number[],
  parameters: RoundParameters,
): PlayRound {
  const bias = clampParameter(slug, "prizeBias", parameters.prizeBias);
  const tuned = weights.map((weight, index) => (segments[index] > 0 ? weight + bias : weight));
  const index = weightedIndex(tuned);
  const multiplier = segments[index] ?? 0;
  const title = multiplier <= 0 ? "No prize" : multiplier >= 50 ? "Jackpot" : `${multiplier}x segment`;
  return {
    multiplier,
    title,
    presentation: { kind, segments, index },
  };
}

function coinFlip(choice: unknown, parameters: RoundParameters): PlayRound {
  const call = String(choice ?? "").toUpperCase();
  if (call !== "HEADS" && call !== "TAILS") {
    throw new AppError(400, "Call heads or tails first.");
  }
  const won = randomInt(100) < clampParameter("coin-flip", "winChance", parameters.winChance);
  const face = won ? call : call === "HEADS" ? "TAILS" : "HEADS";
  return {
    multiplier: won ? 1.9 : 0,
    title: won ? `${face} wins` : `${face}`,
    presentation: { kind: "coin", call, face, won },
  };
}

function treasureBox(choice: unknown, parameters: RoundParameters): PlayRound {
  const index = wholeNumber(choice);
  if (index === null || index < 0 || index > 3) {
    throw new AppError(400, "Choose a box first.");
  }
  const table = [0, 1, 2, 4, 8, 12];
  const weights = [clampParameter("treasure-box", "emptyWeight", parameters.emptyWeight), 22, 10, 5, 2, 1];
  const rewards = [0, 1, 2, 3].map(() => pickWeighted(table, weights));
  rewards[index] = pickWeighted(table, weights);
  return {
    multiplier: rewards[index],
    title: rewards[index] > 0 ? `Box ${index + 1}` : "Empty box",
    presentation: { kind: "boxes", rewards, index },
  };
}

function cashMatch(parameters: RoundParameters): PlayRound {
  const boost = clampParameter("cash-match", "pairBoost", parameters.pairBoost);
  const tiers = [
    { pairs: 0, multiplier: 0, weight: 55 },
    { pairs: 1, multiplier: 1, weight: 30 + boost },
    { pairs: 2, multiplier: 3, weight: 12 + boost },
    { pairs: 3, multiplier: 8, weight: 3 + boost },
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

function diamondDrop(parameters: RoundParameters): PlayRound {
  const boost = clampParameter("diamond-drop", "comboBoost", parameters.comboBoost);
  const combos = [0, 1, 2, 3, 4, 5];
  const weights = [50, 28 + boost, 14 + boost, 5 + boost, 2 + boost, 1 + boost];
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

function bonusBurst(parameters: RoundParameters): PlayRound {
  const boost = clampParameter("bonus-burst", "collectBoost", parameters.collectBoost);
  const counts = [0, 1, 2, 3, 4, 5];
  const weights = [40, 28 + boost, 16 + boost, 9 + boost, 5 + boost, 2 + boost];
  const payouts = [0, 0.5, 1, 2, 4, 8];
  const count = counts[weightedIndex(weights)];
  return {
    multiplier: payouts[count],
    title: count > 0 ? `${count} collected` : "Burst missed",
    presentation: { kind: "burst", count, seconds: 6 },
  };
}

const CARD_RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"] as const;
const CARD_SUITS = ["hearts", "diamonds", "clubs", "spades"] as const;

function higherCard(): PlayRound {
  const deck: { rank: string; suit: string }[] = [];
  for (const suit of CARD_SUITS) {
    for (const rank of CARD_RANKS) {
      deck.push({ rank, suit });
    }
  }
  for (let index = deck.length - 1; index > 0; index -= 1) {
    const swap = randomInt(index + 1);
    const current = deck[index];
    deck[index] = deck[swap];
    deck[swap] = current;
  }
  const player = deck[0];
  const house = deck[1];
  const playerValue = cardRank(player.rank);
  const houseValue = cardRank(house.rank);
  if (playerValue > houseValue) {
    return {
      multiplier: 2,
      title: "Higher card",
      presentation: { kind: "cards", player, house, outcome: "win" },
    };
  }
  if (playerValue === houseValue) {
    return {
      multiplier: 1,
      title: "Push",
      presentation: { kind: "cards", player, house, outcome: "push" },
    };
  }
  return {
    multiplier: 0,
    title: "House wins",
    presentation: { kind: "cards", player, house, outcome: "lose" },
  };
}

function cardRank(rank: string): number {
  if (rank === "A") return 14;
  if (rank === "K") return 13;
  if (rank === "Q") return 12;
  if (rank === "J") return 11;
  return Number(rank);
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
