import Phaser from "phaser";

const INK = 0x1a1408;
const PAPER = 0xf3efe4;
const GOLD = 0xe2b15a;

const SYMBOL_TINT: Record<string, number> = {
  COIN: 0xe2b15a,
  DOLLAR: 0x3ddc97,
  STAR: 0xf0d59a,
  DIAMOND: 0x7ec8ff,
  SEVEN: 0xe36b6b,
  BONUS: 0xd28bff,
};

export function backdrop(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, theme: "felt" | "water" | "sky" | "night" | "wood") {
  if (theme === "water") {
    layer.add(scene.add.rectangle(480, 180, 820, 160, 0x1c3d66));
    layer.add(scene.add.ellipse(480, 360, 760, 220, 0x0e4d63));
    layer.add(scene.add.ellipse(480, 390, 620, 90, 0x14667a, 0.45));
    return;
  }
  if (theme === "sky") {
    layer.add(scene.add.rectangle(480, 200, 820, 300, 0x1d4d86));
    layer.add(scene.add.ellipse(220, 250, 140, 36, 0xf3efe4, 0.18));
    layer.add(scene.add.ellipse(620, 180, 180, 40, 0xf3efe4, 0.14));
    layer.add(scene.add.rectangle(480, 400, 820, 120, 0x163026));
    return;
  }
  if (theme === "night") {
    layer.add(scene.add.rectangle(480, 250, 820, 360, 0x10141f));
    for (const [x, y] of [
      [180, 120],
      [300, 180],
      [700, 140],
      [780, 220],
      [540, 110],
    ] as const) {
      layer.add(scene.add.circle(x, y, 2, 0xf0d59a, 0.8));
    }
    return;
  }
  if (theme === "wood") {
    layer.add(scene.add.rectangle(480, 250, 820, 360, 0x3a2a1c));
    layer.add(scene.add.rectangle(480, 250, 760, 300, 0x2a1d14).setStrokeStyle(4, 0xc6a15a));
    return;
  }
  layer.add(scene.add.ellipse(480, 280, 780, 340, 0x0f3d2c));
  layer.add(scene.add.ellipse(480, 290, 640, 240, 0x14573a, 0.65));
}

export function symbolToken(scene: Phaser.Scene, symbol: string, hot = false) {
  const tint = SYMBOL_TINT[symbol] ?? GOLD;
  const group = scene.add.container(0, 0);
  group.add(scene.add.rectangle(0, 0, 78, 70, hot ? tint : 0x101410).setStrokeStyle(3, tint));
  group.add(icon(scene, symbol, hot ? INK : tint));
  return group;
}

export function fishSprite(scene: Phaser.Scene, id: string) {
  const color = id === "golden" || id === "legend" ? GOLD : id === "blue" ? 0x3d8fd1 : id === "small" ? 0x3ddc97 : 0x8d8374;
  const group = scene.add.container(0, 0);
  group.add(scene.add.triangle(-52, 0, 0, 18, -30, 0, 0, -18, color));
  group.add(scene.add.ellipse(0, 0, 92, 42, color));
  group.add(scene.add.circle(24, -8, 5, PAPER));
  group.add(scene.add.circle(26, -8, 2, INK));
  if (id === "legend") {
    group.add(scene.add.star(0, 6, 5, 4, 9, GOLD));
  }
  return group;
}

export function bottleSprite(scene: Phaser.Scene, bonus: boolean) {
  const glass = bonus ? GOLD : 0x4aa3c7;
  const group = scene.add.container(0, 0);
  group.add(scene.add.rectangle(0, 16, 36, 78, glass).setStrokeStyle(2, PAPER));
  group.add(scene.add.rectangle(0, -32, 14, 28, 0xf3efe4));
  group.add(scene.add.rectangle(-8, 10, 6, 48, 0xffffff, 0.28));
  return group;
}

export function planeSprite(scene: Phaser.Scene) {
  const group = scene.add.container(0, 0);
  group.add(scene.add.triangle(-8, 0, -16, 0, 18, -26, 18, 26, GOLD));
  group.add(scene.add.rectangle(6, 0, 78, 16, PAPER));
  group.add(scene.add.triangle(-46, 0, 0, 12, -18, 0, 0, -12, 0xc6a15a));
  group.add(scene.add.circle(36, 0, 4, 0x1d4d86));
  return group;
}

export function coinSprite(scene: Phaser.Scene, face: string) {
  const group = scene.add.container(0, 0);
  group.add(scene.add.circle(0, 0, 74, 0xc6a15a));
  group.add(scene.add.circle(0, 0, 60, GOLD));
  group.add(scene.add.circle(0, 0, 48, 0xf0d59a));
  const label = face === "TAILS" ? "T" : face === "HEADS" ? "H" : "•";
  group.add(scene.add.text(0, 0, label, { fontFamily: "Georgia, serif", fontSize: "42px", color: "#1a1408" }).setOrigin(0.5));
  return group;
}

export function dieSprite(scene: Phaser.Scene, face: number) {
  const group = scene.add.container(0, 0);
  group.add(scene.add.rectangle(0, 0, 86, 86, PAPER).setStrokeStyle(4, 0xc6a15a));
  for (const [x, y] of pips(face)) {
    group.add(scene.add.circle(x, y, 6, INK));
  }
  return group;
}

export function cardSprite(scene: Phaser.Scene, rank: string, suit: string) {
  const red = suit === "hearts" || suit === "diamonds";
  const mark = suit === "hearts" ? "♥" : suit === "diamonds" ? "♦" : suit === "clubs" ? "♣" : "♠";
  const group = scene.add.container(0, 0);
  group.add(scene.add.rectangle(0, 0, 120, 168, PAPER).setStrokeStyle(3, 0xc6a15a));
  group.add(
    scene.add
      .text(0, -8, `${rank}\n${mark}`, {
        fontFamily: "Georgia, serif",
        fontSize: "36px",
        color: red ? "#c24545" : "#1a1408",
        align: "center",
      })
      .setOrigin(0.5),
  );
  return group;
}

export function cardBack(scene: Phaser.Scene) {
  const group = scene.add.container(0, 0);
  group.add(scene.add.rectangle(0, 0, 100, 78, 0x163026).setStrokeStyle(3, GOLD));
  group.add(scene.add.star(0, 0, 5, 8, 18, GOLD));
  return group;
}

export function targetSprite(scene: Phaser.Scene, bonus: boolean) {
  const group = scene.add.container(0, 0);
  group.add(scene.add.circle(0, 0, bonus ? 40 : 32, PAPER));
  group.add(scene.add.circle(0, 0, bonus ? 28 : 22, 0xc24545));
  group.add(scene.add.circle(0, 0, bonus ? 14 : 10, GOLD));
  return group;
}

export function chestSprite(scene: Phaser.Scene, open: boolean, label: string) {
  const group = scene.add.container(0, 0);
  group.add(scene.add.rectangle(0, 16, 116, 78, 0x6b3d22).setStrokeStyle(3, GOLD));
  group.add(scene.add.rectangle(0, open ? -46 : -24, 124, 28, GOLD));
  group.add(
    scene.add
      .text(0, 16, open ? label : "", { fontFamily: "Georgia, serif", fontSize: "28px", color: "#f0d59a" })
      .setOrigin(0.5),
  );
  return group;
}

export function gemSprite(scene: Phaser.Scene, name: string) {
  const color = name === "RUBY" ? 0xc24545 : name === "GOLD" ? GOLD : name === "JADE" ? 0x3d8f62 : 0x3d6b8f;
  const group = scene.add.container(0, 0);
  group.add(scene.add.star(0, 0, 4, 10, 22, color));
  return group;
}

export function sparks(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, x: number, y: number, tint = GOLD) {
  for (let index = 0; index < 10; index += 1) {
    const bit = scene.add.circle(x, y, 4, tint);
    layer.add(bit);
    const angle = (index / 10) * Math.PI * 2;
    scene.tweens.add({
      targets: bit,
      x: x + Math.cos(angle) * 70,
      y: y + Math.sin(angle) * 48,
      alpha: 0,
      duration: 480,
      ease: "Quad.easeOut",
    });
  }
}

function icon(scene: Phaser.Scene, symbol: string, color: number) {
  if (symbol === "STAR" || symbol === "BONUS") {
    return scene.add.star(0, 0, 5, symbol === "BONUS" ? 8 : 10, symbol === "BONUS" ? 20 : 24, color);
  }
  if (symbol === "DIAMOND") {
    return scene.add.star(0, 0, 2, 8, 24, color);
  }
  if (symbol === "COIN") {
    const group = scene.add.container(0, 0);
    group.add(scene.add.circle(0, 0, 22, color));
    group.add(scene.add.text(0, 0, "$", { fontFamily: "Georgia, serif", fontSize: "22px", color: "#1a1408" }).setOrigin(0.5));
    return group;
  }
  const glyph = symbol === "SEVEN" ? "7" : symbol === "DOLLAR" ? "$" : symbol.slice(0, 1);
  return scene.add.text(0, 0, glyph, { fontFamily: "Georgia, serif", fontSize: "32px", color: `#${color.toString(16).padStart(6, "0")}` }).setOrigin(0.5);
}

function pips(face: number): Array<[number, number]> {
  const map: Record<number, Array<[number, number]>> = {
    1: [[0, 0]],
    2: [[-18, -18], [18, 18]],
    3: [[-18, -18], [0, 0], [18, 18]],
    4: [[-18, -18], [18, -18], [-18, 18], [18, 18]],
    5: [[-18, -18], [18, -18], [0, 0], [-18, 18], [18, 18]],
    6: [[-18, -20], [18, -20], [-18, 0], [18, 0], [-18, 20], [18, 20]],
  };
  return map[face] ?? map[1];
}
