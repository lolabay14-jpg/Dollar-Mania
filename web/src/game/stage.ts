import Phaser from "phaser";

export type RoundView = {
  title: string;
  winAmount: number;
  betAmount: number;
  presentation: Record<string, unknown> | null;
};

const INK = 0x141b16;
const GOLD = "#e2b15a";
const PAPER = "#f3efe4";
const GOOD = "#3ddc97";

export function mountStage(parent: HTMLElement, round: RoundView | null) {
  const game = new Phaser.Game({
    type: Phaser.AUTO,
    parent,
    width: 960,
    height: 540,
    backgroundColor: INK,
    scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
    scene: new RoundScene(round),
  });
  return () => {
    game.destroy(true);
  };
}

class RoundScene extends Phaser.Scene {
  constructor(private readonly round: RoundView | null) {
    super("round");
  }

  create() {
    this.add.rectangle(480, 270, 920, 500, 0x1a211c).setStrokeStyle(2, 0x314037);
    if (!this.round?.presentation) {
      this.center("Place a bet. The server decides the result, then this table plays it.", PAPER, 22);
      return;
    }
    const kind = String(this.round.presentation.kind ?? "");
    const painted = paint(this, kind, this.round.presentation);
    if (!painted) {
      this.center(this.round.title || kind || "Round complete", PAPER, 28);
    }
    const won = this.round.winAmount > 0;
    this.add
      .text(480, 492, `${this.round.title}   ·   ${won ? `Won ${this.round.winAmount}` : "No win"}`, {
        fontFamily: "Georgia, serif",
        fontSize: "22px",
        color: won ? GOOD : PAPER,
      })
      .setOrigin(0.5);
  }

  center(label: string, color: string, size: number) {
    this.add.text(480, 250, label, { fontFamily: "Georgia, serif", fontSize: `${size}px`, color, align: "center", wordWrap: { width: 760 } }).setOrigin(0.5);
  }
}

function paint(scene: Phaser.Scene, kind: string, data: Record<string, unknown>) {
  if (kind === "reels") return paintReels(scene, data);
  if (kind === "rush") return paintRush(scene, data);
  if (kind === "scratch") return paintCells(scene, asStrings(data.cells), asNumbers(data.matches), 3);
  if (kind === "wheel" || kind === "jackpot" || kind === "fruit" || kind === "lucky" || kind === "spinner" || kind === "diamond") {
    return paintWheel(scene, data);
  }
  if (kind === "dice") return paintDice(scene, data);
  if (kind === "number") return paintNumber(scene, data);
  if (kind === "fishing") return paintFishing(scene, data);
  if (kind === "targets") return paintTargets(scene, data);
  if (kind === "flight") return paintFlight(scene, data);
  if (kind === "bottles") return paintBottles(scene, data);
  if (kind === "mystery") return paintMystery(scene, data);
  if (kind === "coin") return paintCoin(scene, data);
  if (kind === "boxes") return paintBoxes(scene, data);
  if (kind === "match") return paintCells(scene, asStrings(data.cards), asNumbers(data.matched), 3);
  if (kind === "drop") return paintDrop(scene, data);
  if (kind === "burst") return paintBurst(scene, data);
  if (kind === "cards") return paintCards(scene, data);
  return false;
}

function paintReels(scene: Phaser.Scene, data: Record<string, unknown>) {
  const grid = asArray(data.grid).map(asStrings);
  const highlights = new Set(asNumbers(data.highlights));
  const columns = Math.max(grid.length, 1);
  grid.forEach((column, columnIndex) => {
    const x = 480 - ((columns - 1) * 110) / 2 + columnIndex * 110;
    column.slice(0, 3).forEach((symbol, row) => {
      const y = 150 + row * 90;
      const hot = row === 1 && highlights.has(columnIndex);
      const token = scene.add.circle(x, y - 80, 36, hot ? 0xe2b15a : 0x101410).setStrokeStyle(2, hot ? 0xf0d59a : 0x314037);
      const label = scene.add.text(x, y - 80, glyph(symbol), { fontFamily: "Georgia, serif", fontSize: "20px", color: hot ? "#1a1408" : PAPER }).setOrigin(0.5);
      scene.tweens.add({ targets: [token, label], y: `+=80`, duration: 500 + columnIndex * 140, ease: "Cubic.easeOut" });
    });
  });
  return true;
}

function paintRush(scene: Phaser.Scene, data: Record<string, unknown>) {
  const lane = asNumber(data.lane, -1);
  const winning = asNumber(data.winningLane, -1);
  ["Left", "Middle", "Right"].forEach((name, index) => {
    const x = 250 + index * 230;
    const chosen = index === lane;
    const hit = index === winning;
    scene.add.rectangle(x, 250, 160, 280, hit ? 0x245c40 : 0x101410).setStrokeStyle(3, chosen ? 0xe2b15a : 0x314037);
    scene.add.text(x, 250, hit ? "HIT" : name, { fontFamily: "Georgia, serif", fontSize: "28px", color: hit ? GOOD : PAPER }).setOrigin(0.5);
  });
  return true;
}

function paintWheel(scene: Phaser.Scene, data: Record<string, unknown>) {
  const segments = asNumbers(data.segments);
  const symbols = asStrings(data.symbols);
  const index = asNumber(data.index);
  const count = Math.max(segments.length, 1);
  const wheel = scene.add.container(480, 250);
  wheel.add(scene.add.circle(0, 0, 150, 0x101410).setStrokeStyle(4, 0xe2b15a));
  const slice = (Math.PI * 2) / count;
  segments.forEach((value, segmentIndex) => {
    const angle = segmentIndex * slice - Math.PI / 2;
    const label = symbols[segmentIndex] || `${value}x`;
    wheel.add(
      scene.add
        .text(Math.cos(angle) * 100, Math.sin(angle) * 100, label, {
          fontFamily: "Georgia, serif",
          fontSize: "14px",
          color: segmentIndex === index ? GOLD : PAPER,
        })
        .setOrigin(0.5),
    );
  });
  scene.add.triangle(480, 78, 0, 0, 18, 0, 9, 22, 0xe2b15a);
  scene.tweens.add({
    targets: wheel,
    angle: 360 * 4 - (index * 360) / count,
    duration: 1400,
    ease: "Cubic.easeOut",
  });
  return true;
}

function paintDice(scene: Phaser.Scene, data: Record<string, unknown>) {
  const dice = asNumbers(data.dice);
  dice.slice(0, 2).forEach((face, index) => {
    const x = 400 + index * 160;
    const die = scene.add.rectangle(x, 180, 90, 90, 0xf3efe4);
    const text = scene.add.text(x, 180, String(face), { fontFamily: "Georgia, serif", fontSize: "36px", color: "#1a1408" }).setOrigin(0.5);
    scene.tweens.add({ targets: [die, text], y: 250, duration: 600, ease: "Bounce.easeOut" });
  });
  return true;
}

function paintNumber(scene: Phaser.Scene, data: Record<string, unknown>) {
  scene.add.text(330, 220, `Pick ${asNumber(data.pick)}`, { fontFamily: "Georgia, serif", fontSize: "32px", color: PAPER }).setOrigin(0.5);
  const draw = scene.add.text(630, 220, `Draw ${asNumber(data.draw)}`, { fontFamily: "Georgia, serif", fontSize: "32px", color: GOLD }).setOrigin(0.5).setAlpha(0);
  scene.tweens.add({ targets: draw, alpha: 1, duration: 500, delay: 400 });
  return true;
}

function paintFishing(scene: Phaser.Scene, data: Record<string, unknown>) {
  scene.add.ellipse(480, 300, 520, 180, 0x163246);
  const fish = scene.add.ellipse(220, 300, 70, 36, 0xe2b15a);
  scene.add.text(480, 160, `${asString(data.name, "Fish")} · ${asString(data.rarity)}`, { fontFamily: "Georgia, serif", fontSize: "28px", color: PAPER }).setOrigin(0.5);
  scene.tweens.add({ targets: fish, x: 700, duration: 1200, yoyo: true, repeat: 1 });
  return true;
}

function paintTargets(scene: Phaser.Scene, data: Record<string, unknown>) {
  asArray(data.targets).forEach((item, index) => {
    const target = asRecord(item);
    const x = 180 + (index % 6) * 120;
    const ring = scene.add.circle(x, 230, asString(target.size) === "small" ? 24 : 36, target.bonus ? 0xe2b15a : 0x8f3d3d).setScale(0);
    scene.tweens.add({ targets: ring, scale: 1, duration: 280, delay: asNumber(target.delay) * 180 });
    scene.add.text(x, 300, `${asNumber(target.points)}`, { fontFamily: "Georgia, serif", fontSize: "16px", color: PAPER }).setOrigin(0.5);
  });
  return true;
}

function paintFlight(scene: Phaser.Scene, data: Record<string, unknown>) {
  scene.add.triangle(160, 250, 0, 20, 50, 0, 0, -20, 0xf3efe4);
  asArray(data.coins).forEach((item, index) => {
    const coin = asRecord(item);
    const y = 140 + asNumber(coin.lane) * 90;
    const token = scene.add.circle(860, y, 18, asNumber(coin.points) > 0 ? 0xe2b15a : 0x314037);
    scene.tweens.add({ targets: token, x: 220, duration: 900, delay: index * 120 });
  });
  return true;
}

function paintBottles(scene: Phaser.Scene, data: Record<string, unknown>) {
  asArray(data.bottles).forEach((item, index) => {
    const bottle = asRecord(item);
    const x = 200 + index * 110;
    const body = scene.add.rectangle(x, 80, 36, 90, bottle.bonus ? 0xe2b15a : 0x3d6b8f);
    scene.tweens.add({ targets: body, y: 250, duration: 500, delay: asNumber(bottle.delay) * 160, ease: "Bounce.easeOut" });
    scene.add.text(x, 330, `${asNumber(bottle.points)}`, { fontFamily: "Georgia, serif", fontSize: "16px", color: PAPER }).setOrigin(0.5);
  });
  return true;
}

function paintMystery(scene: Phaser.Scene, data: Record<string, unknown>) {
  const box = scene.add.rectangle(480, 230, 140, 140, 0xe2b15a);
  scene.add.text(480, 230, `${asNumber(data.prize)}x`, { fontFamily: "Georgia, serif", fontSize: "36px", color: "#1a1408" }).setOrigin(0.5);
  scene.tweens.add({ targets: box, scale: 1.08, yoyo: true, duration: 400 });
  return true;
}

function paintCoin(scene: Phaser.Scene, data: Record<string, unknown>) {
  const face = scene.add.circle(480, 230, 80, 0xe2b15a);
  const label = scene.add.text(480, 230, asString(data.face, "COIN"), { fontFamily: "Georgia, serif", fontSize: "22px", color: "#1a1408" }).setOrigin(0.5);
  scene.tweens.add({ targets: [face, label], angle: 360, duration: 700 });
  return true;
}

function paintBoxes(scene: Phaser.Scene, data: Record<string, unknown>) {
  const rewards = asNumbers(data.rewards);
  const chosen = asNumber(data.index);
  rewards.forEach((reward, index) => {
    const x = 220 + index * 170;
    const open = index === chosen;
    scene.add.rectangle(x, 240, 110, 110, open ? 0xe2b15a : 0x101410).setStrokeStyle(2, 0x314037);
    scene.add.text(x, 240, open ? `${reward}x` : "?", { fontFamily: "Georgia, serif", fontSize: "28px", color: open ? "#1a1408" : PAPER }).setOrigin(0.5);
  });
  return true;
}

function paintCells(scene: Phaser.Scene, cells: string[], matches: number[], columns: number) {
  const hot = new Set(matches);
  cells.forEach((cell, index) => {
    const x = 250 + (index % columns) * 150;
    const y = 160 + Math.floor(index / columns) * 120;
    scene.add.rectangle(x, y, 110, 80, hot.has(index) ? 0xe2b15a : 0x101410).setStrokeStyle(2, 0x314037);
    scene.add.text(x, y, glyph(cell), { fontFamily: "Georgia, serif", fontSize: "22px", color: hot.has(index) ? "#1a1408" : PAPER }).setOrigin(0.5);
  });
  return true;
}

function paintDrop(scene: Phaser.Scene, data: Record<string, unknown>) {
  asStrings(data.gems).forEach((gem, index) => {
    const y = -20;
    const token = scene.add.circle(180 + index * 110, y, 28, gemColor(gem));
    scene.add.text(180 + index * 110, 330, gem, { fontFamily: "Georgia, serif", fontSize: "14px", color: PAPER }).setOrigin(0.5);
    scene.tweens.add({ targets: token, y: 230, duration: 400, delay: index * 90, ease: "Bounce.easeOut" });
  });
  return true;
}

function paintBurst(scene: Phaser.Scene, data: Record<string, unknown>) {
  const count = asNumber(data.count);
  for (let index = 0; index < 6; index += 1) {
    const orb = scene.add.circle(480, 250, 16, index < count ? 0xe2b15a : 0x314037);
    const angle = (index / 6) * Math.PI * 2;
    scene.tweens.add({ targets: orb, x: 480 + Math.cos(angle) * 140, y: 250 + Math.sin(angle) * 100, duration: 600 });
  }
  return true;
}

function paintCards(scene: Phaser.Scene, data: Record<string, unknown>) {
  drawCard(scene, 360, "You", asRecord(data.player));
  drawCard(scene, 600, "House", asRecord(data.house));
  return true;
}

function drawCard(scene: Phaser.Scene, x: number, caption: string, card: Record<string, unknown>) {
  scene.add.rectangle(x, 240, 140, 190, 0xf3efe4);
  scene.add.text(x, 230, `${asString(card.rank)} ${asString(card.suit)}`, { fontFamily: "Georgia, serif", fontSize: "22px", color: "#1a1408", align: "center", wordWrap: { width: 120 } }).setOrigin(0.5);
  scene.add.text(x, 360, caption, { fontFamily: "Georgia, serif", fontSize: "18px", color: PAPER }).setOrigin(0.5);
}

function glyph(symbol: string) {
  const marks: Record<string, string> = {
    COIN: "Coin",
    DOLLAR: "$",
    STAR: "Star",
    DIAMOND: "Diamond",
    SEVEN: "7",
    BONUS: "Bonus",
  };
  return marks[symbol] ?? symbol;
}

function gemColor(gem: string) {
  if (gem === "RUBY") return 0x8f3d3d;
  if (gem === "GOLD") return 0xe2b15a;
  if (gem === "JADE") return 0x3d8f62;
  return 0x3d6b8f;
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" ? (value as Record<string, unknown>) : {};
}

function asArray(value: unknown) {
  return Array.isArray(value) ? value : [];
}

function asStrings(value: unknown) {
  return asArray(value).map((item) => String(item));
}

function asNumbers(value: unknown) {
  return asArray(value).map((item) => asNumber(item));
}

function asNumber(value: unknown, fallback = 0) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function asString(value: unknown, fallback = "") {
  return typeof value === "string" ? value : fallback;
}
