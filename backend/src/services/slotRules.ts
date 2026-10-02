export const SYMBOLS = ["COIN", "DOLLAR", "STAR", "DIAMOND", "SEVEN", "BONUS"] as const;

export type SymbolId = (typeof SYMBOLS)[number];

export type SlotRules = {
  weights: Record<SymbolId, number>;
  threeKind: Record<SymbolId, number>;
  pair: Partial<Record<SymbolId, number>>;
};

export type SpinMath = {
  grid: SymbolId[][];
  payline: SymbolId[];
  multiplier: number;
  title: string;
  highlights: number[];
};

const LUCKY_DOLLAR: SlotRules = {
  weights: { COIN: 26, DOLLAR: 22, STAR: 16, DIAMOND: 10, SEVEN: 7, BONUS: 3 },
  threeKind: { COIN: 3, DOLLAR: 5, STAR: 8, DIAMOND: 14, SEVEN: 25, BONUS: 40 },
  pair: { COIN: 1, DOLLAR: 2, STAR: 2, BONUS: 4 },
};

const GOLDEN_FORTUNE: SlotRules = {
  weights: { COIN: 30, DOLLAR: 24, STAR: 16, DIAMOND: 8, SEVEN: 5, BONUS: 2 },
  threeKind: { COIN: 3, DOLLAR: 5, STAR: 10, DIAMOND: 18, SEVEN: 30, BONUS: 50 },
  pair: { DOLLAR: 2, DIAMOND: 4, SEVEN: 6, BONUS: 8 },
};

const DOLLAR_RUSH: SlotRules = {
  weights: { COIN: 28, DOLLAR: 18, STAR: 14, DIAMOND: 8, SEVEN: 6, BONUS: 5 },
  threeKind: { COIN: 2, DOLLAR: 5, STAR: 8, DIAMOND: 16, SEVEN: 30, BONUS: 60 },
  pair: { DOLLAR: 2, STAR: 3, SEVEN: 5, BONUS: 8 },
};

const RULES_BY_SLUG: Record<string, SlotRules> = {
  "lucky-dollar": LUCKY_DOLLAR,
  "golden-fortune": GOLDEN_FORTUNE,
  "dollar-rush": DOLLAR_RUSH,
  lucky_dollar: LUCKY_DOLLAR,
  golden_fortune: GOLDEN_FORTUNE,
  dollar_rush: DOLLAR_RUSH,
};

export function rulesForSlug(slug: string): SlotRules {
  return RULES_BY_SLUG[slug] ?? LUCKY_DOLLAR;
}

export function rollGrid(rules: SlotRules, random: () => number = Math.random): SymbolId[][] {
  return [0, 1, 2].map(() => [0, 1, 2].map(() => pickSymbol(rules, random)));
}

export function evaluateGrid(rules: SlotRules, grid: SymbolId[][]): SpinMath {
  const payline = grid.map((column) => column[1]) as SymbolId[];
  if (payline[0] === payline[1] && payline[1] === payline[2]) {
    const multiplier = rules.threeKind[payline[0]] ?? 0;
    if (multiplier > 0) {
      return {
        grid,
        payline,
        multiplier,
        title: `Three ${displayName(payline[0])}  ·  ${multiplier}x`,
        highlights: [0, 1, 2],
      };
    }
  }

  for (const symbol of Object.keys(rules.pair) as SymbolId[]) {
    const matched: number[] = [];
    payline.forEach((value, index) => {
      if (value === symbol) {
        matched.push(index);
      }
    });
    if (matched.length === 2) {
      const multiplier = rules.pair[symbol] ?? 0;
      return {
        grid,
        payline,
        multiplier,
        title: `Two ${displayName(symbol)}  ·  ${multiplier}x`,
        highlights: matched,
      };
    }
  }

  return {
    grid,
    payline,
    multiplier: 0,
    title: "No win",
    highlights: [],
  };
}

export function playRound(rules: SlotRules, random: () => number = Math.random): SpinMath {
  return evaluateGrid(rules, rollGrid(rules, random));
}

function pickSymbol(rules: SlotRules, random: () => number): SymbolId {
  const total = SYMBOLS.reduce((sum, symbol) => sum + rules.weights[symbol], 0);
  let cursor = random() * total;
  for (const symbol of SYMBOLS) {
    cursor -= rules.weights[symbol];
    if (cursor < 0) {
      return symbol;
    }
  }
  return "COIN";
}

function displayName(symbol: SymbolId): string {
  return symbol.charAt(0) + symbol.slice(1).toLowerCase();
}
