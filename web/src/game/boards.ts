import Phaser from "phaser";
import {
  backdrop,
  bottleSprite,
  cardBack,
  cardSprite,
  chestSprite,
  coinSprite,
  dieSprite,
  fishSprite,
  gemSprite,
  planeSprite,
  sparks,
  symbolToken,
  targetSprite,
} from "@/game/art";

export type BoardMode = "idle" | "drawing" | "result";

const SLUG_KIND: Record<string, string> = {
  "lucky-dollar": "reels",
  "golden-fortune": "reels",
  "dollar-rush": "rush",
  "scratch-mania": "scratch",
  "lucky-spin": "wheel",
  "jackpot-wheel": "jackpot",
  "fruit-spin": "fruit",
  "lucky-wheel": "lucky",
  "prize-spinner": "spinner",
  "diamond-spin": "diamond",
  "coin-flip": "coin",
  "treasure-box": "boxes",
  "mystery-box": "mystery",
  "cash-match": "match",
  "diamond-drop": "drop",
  "bonus-burst": "burst",
  "higher-card": "cards",
  fishing: "fishing",
  "target-blast": "targets",
  "aeroplane-rush": "flight",
  "bottle-blast": "bottles",
  dice: "dice",
  "lucky-number": "number",
};

export function kindForSlug(slug: string) {
  return SLUG_KIND[slug] ?? "reels";
}

export function renderBoard(
  scene: Phaser.Scene,
  layer: Phaser.GameObjects.Container,
  kind: string,
  data: Record<string, unknown> | null,
  masks: Phaser.GameObjects.Graphics[],
  mode: BoardMode,
) {
  if (kind === "reels") return paintReels(scene, layer, data, masks, mode);
  if (kind === "rush") return paintRush(scene, layer, data, mode);
  if (kind === "scratch") return paintTiles(scene, layer, data ? asStrings(data.cells) : placeholder(6), data ? new Set(asNumbers(data.matches)) : new Set(), mode);
  if (isWheel(kind)) return paintWheel(scene, layer, data, mode);
  if (kind === "dice") return paintDice(scene, layer, data, mode);
  if (kind === "number") return paintNumber(scene, layer, data, mode);
  if (kind === "fishing") return paintFishing(scene, layer, data, mode);
  if (kind === "targets") return paintTargets(scene, layer, data, mode);
  if (kind === "flight") return paintFlight(scene, layer, data, mode);
  if (kind === "bottles") return paintBottles(scene, layer, data, mode);
  if (kind === "mystery") return paintMystery(scene, layer, data, mode);
  if (kind === "coin") return paintCoin(scene, layer, data, mode);
  if (kind === "boxes") return paintBoxes(scene, layer, data, mode);
  if (kind === "match") return paintTiles(scene, layer, data ? asStrings(data.cards) : placeholder(6), data ? new Set(asNumbers(data.matched)) : new Set(), mode);
  if (kind === "drop") return paintDrop(scene, layer, data, mode);
  if (kind === "burst") return paintBurst(scene, layer, data, mode);
  if (kind === "cards") return paintCards(scene, layer, data, mode);
  return false;
}

function paintReels(
  scene: Phaser.Scene,
  layer: Phaser.GameObjects.Container,
  data: Record<string, unknown> | null,
  masks: Phaser.GameObjects.Graphics[],
  mode: BoardMode,
) {
  backdrop(scene, layer, "night");
  const grid = data ? asArray(data.grid).map(asStrings).filter((column) => column.length > 0) : [];
  const columns = grid.length > 0 ? grid : [placeholder(3), placeholder(3), placeholder(3)];
  const highlights = new Set(data ? asNumbers(data.highlights) : []);
  const colW = 92;
  const rowH = 80;
  const gap = 12;
  const origin = 480 - ((columns.length - 1) * (colW + gap)) / 2;
  const windowTop = 118;
  layer.add(scene.add.rectangle(480, windowTop + rowH * 1.5, columns.length * (colW + gap) + 24, rowH * 3 + 24, 0x1a1408).setStrokeStyle(6, 0xe2b15a));

  columns.forEach((column, columnIndex) => {
    const x = origin + columnIndex * (colW + gap);
    const maskGraphics = scene.make.graphics({ x: 0, y: 0 }, false);
    maskGraphics.fillStyle(0xffffff);
    maskGraphics.fillRect(x - colW / 2, windowTop, colW, rowH * 3);
    masks.push(maskGraphics);
    const reel = scene.add.container(x, 0);
    reel.setMask(maskGraphics.createGeometryMask());
    const filler = ["COIN", "STAR", "SEVEN", "DOLLAR", "DIAMOND", "BONUS"];
    const finals = column.slice(0, 3);
    const strip = [...filler, ...filler, ...filler, ...finals];
    strip.forEach((symbol, index) => {
      const hot = mode === "result" && index === strip.length - 2 && highlights.has(columnIndex);
      const token = symbolToken(scene, symbol, hot);
      token.setPosition(0, windowTop + index * rowH + rowH / 2);
      reel.add(token);
    });
    const endY = -(strip.length - 3) * rowH;
    reel.y = endY - rowH * 8;
    scene.tweens.add({
      targets: reel,
      y: endY,
      duration: mode === "result" ? 1100 + columnIndex * 360 : 420,
      ease: mode === "result" ? "Cubic.easeOut" : "Linear",
      repeat: mode === "drawing" ? -1 : 0,
      onRepeat: () => {
        reel.y = endY - rowH * 8;
      },
    });
    layer.add(reel);
    if (mode === "result" && highlights.has(columnIndex)) {
      scene.time.delayedCall(1400 + columnIndex * 200, () => sparks(scene, layer, x, windowTop + rowH * 1.5, 0xe2b15a));
    }
  });
  return true;
}

function paintRush(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "night");
  const chosen = data ? asNumber(data.lane, 1) : 1;
  const winning = data ? asNumber(data.winningLane, -1) : -1;
  ["Left", "Center", "Right"].forEach((name, index) => {
    const x = 250 + index * 230;
    const lane = scene.add.rectangle(x, 270, 150, 280, 0x10141f).setStrokeStyle(3, 0x314037);
    layer.add(lane);
    layer.add(scene.add.text(x, 150, name, { fontFamily: "Georgia, serif", fontSize: "16px", color: "#b4aa98" }).setOrigin(0.5));
    for (let dash = 0; dash < 4; dash += 1) {
      layer.add(scene.add.rectangle(x, 190 + dash * 50, 8, 22, 0xe2b15a, 0.35));
    }
  });
  const runner = scene.add.container(250 + chosen * 230, 180);
  runner.add(scene.add.circle(0, 0, 18, 0xe2b15a));
  runner.add(scene.add.triangle(0, 6, -10, 16, 0, -8, 10, 16, 0xf3efe4));
  layer.add(runner);
  if (mode === "idle") return true;
  scene.tweens.add({
    targets: runner,
    y: 360,
    duration: mode === "drawing" ? 700 : 900,
    repeat: mode === "drawing" ? -1 : 0,
    ease: "Quad.easeIn",
    onRepeat: () => {
      runner.y = 180;
    },
    onComplete: () => {
      if (mode !== "result") return;
      const hit = chosen === winning && winning >= 0;
      if (hit) sparks(scene, layer, runner.x, 360, 0x3ddc97);
      else runner.setAlpha(0.35);
    },
  });
  return true;
}

function paintWheel(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "night");
  const segments = data ? asNumbers(data.segments) : [1, 0, 2, 0, 5, 0, 1, 0];
  const symbols = data ? asStrings(data.symbols) : [];
  const index = data ? asNumber(data.index) : 0;
  const count = Math.max(segments.length, 1);
  const slice = (Math.PI * 2) / count;
  const wheel = scene.add.container(480, 270);
  const art = scene.add.graphics();
  wheel.add(art);
  for (let segment = 0; segment < count; segment += 1) {
    const start = -Math.PI / 2 + segment * slice - slice / 2;
    art.fillStyle(segment % 2 === 0 ? 0x3a2a1c : 0x1a1408, 1);
    art.slice(0, 0, 150, start, start + slice, false);
    art.fillPath();
  }
  art.lineStyle(8, 0xe2b15a, 1);
  art.strokeCircle(0, 0, 150);
  art.fillStyle(0x101410, 1);
  art.fillCircle(0, 0, 36);
  segments.forEach((value, segment) => {
    const angle = -Math.PI / 2 + segment * slice;
    const token = symbols[segment] ? symbolToken(scene, symbols[segment]) : scene.add.text(0, 0, `${value}x`, { fontFamily: "Georgia, serif", fontSize: "16px", color: "#f3efe4" }).setOrigin(0.5);
    if ("setScale" in token) token.setScale(0.42);
    token.setPosition(Math.cos(angle) * 100, Math.sin(angle) * 100);
    wheel.add(token);
  });
  const pointer = scene.add.triangle(480, 96, 0, 0, 26, 0, 13, 30, 0xe2b15a);
  layer.add([wheel, pointer]);
  scene.tweens.add({
    targets: wheel,
    angle: mode === "result" ? -360 * 6 - (index * 360) / count : -360,
    duration: mode === "result" ? 2600 : 900,
    ease: mode === "result" ? "Cubic.easeOut" : "Linear",
    repeat: mode === "drawing" ? -1 : 0,
    onComplete: () => {
      if (mode === "result") sparks(scene, layer, 480, 130);
    },
  });
  return true;
}

function paintDice(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "felt");
  const faces = data ? asNumbers(data.dice).slice(0, 2) : [1, 1];
  faces.forEach((face, index) => {
    const die = dieSprite(scene, mode === "result" ? face : 1 + ((index * 3) % 6));
    die.setPosition(390 + index * 180, mode === "idle" ? 280 : 80);
    die.setAngle(index === 0 ? -20 : 24);
    layer.add(die);
    if (mode === "idle") return;
    scene.tweens.add({
      targets: die,
      y: 280,
      angle: 0,
      duration: 720,
      delay: index * 140,
      ease: "Bounce.easeOut",
      repeat: mode === "drawing" ? -1 : 0,
      onRepeat: () => {
        die.y = 80;
      },
    });
  });
  return true;
}

function paintNumber(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "night");
  const pick = ball(scene, 330, "Pick", data ? String(asNumber(data.pick)) : "—");
  const draw = ball(scene, 630, "Draw", data ? String(asNumber(data.draw)) : "?");
  pick.setY(mode === "idle" ? 270 : 90);
  draw.setY(90);
  draw.setAlpha(mode === "result" ? 1 : 0.4);
  layer.add([pick, draw]);
  if (mode === "idle") return true;
  scene.tweens.add({ targets: pick, y: 270, duration: 500, ease: "Bounce.easeOut", repeat: mode === "drawing" ? -1 : 0, onRepeat: () => { pick.y = 90; } });
  if (mode === "result") {
    scene.tweens.add({ targets: draw, y: 270, duration: 560, delay: 280, ease: "Bounce.easeOut" });
  }
  return true;
}

function paintFishing(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "water");
  const rod = scene.add.rectangle(180, 120, 8, 90, 0x6b3d22);
  const bobber = scene.add.circle(480, 150, 11, 0xc24545).setStrokeStyle(3, 0xf3efe4);
  layer.add([rod, bobber]);
  const caught = data ? asString(data.fish) !== "none" : false;
  if (mode !== "idle") {
    scene.tweens.add({
      targets: bobber,
      y: 330,
      duration: 650,
      ease: "Quad.easeIn",
      yoyo: mode === "drawing",
      repeat: mode === "drawing" ? -1 : 0,
    });
  }
  if (mode === "result" && data) {
    if (caught) {
      const fish = fishSprite(scene, asString(data.fish));
      fish.setPosition(140, 360);
      layer.add(fish);
      scene.tweens.add({
        targets: fish,
        x: 470,
        y: 250,
        duration: 800,
        delay: 700,
        ease: "Sine.easeOut",
        onComplete: () => sparks(scene, layer, 470, 250, 0x7ec8ff),
      });
    }
    layer.add(
      scene.add
        .text(480, 120, asString(data.name, ""), { fontFamily: "Georgia, serif", fontSize: "26px", color: "#f0d59a" })
        .setOrigin(0.5)
        .setAlpha(0),
    );
  }
  return true;
}

function paintTargets(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "wood");
  const items = data ? asArray(data.targets) : [0, 1, 2].map(() => ({ bonus: false, delay: 0, points: 0 }));
  items.forEach((item, index) => {
    const target = asRecord(item);
    const x = 180 + (index % 6) * 120;
    const board = targetSprite(scene, Boolean(target.bonus));
    board.setPosition(x, 260);
    board.setScale(mode === "result" ? 0 : 1);
    layer.add(board);
    if (mode !== "result") return;
    scene.tweens.add({
      targets: board,
      scale: 1,
      duration: 280,
      delay: asNumber(target.delay) * 200,
      ease: "Back.easeOut",
      onComplete: () => {
        if (asNumber(target.points) > 0) sparks(scene, layer, x, 260, 0xe2b15a);
      },
    });
  });
  return true;
}

function paintFlight(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "sky");
  const plane = planeSprite(scene);
  plane.setPosition(mode === "idle" ? 220 : 80, 250);
  layer.add(plane);
  if (mode !== "idle") {
    scene.tweens.add({ targets: plane, x: 230, duration: 700, ease: "Sine.easeOut", yoyo: mode === "drawing", repeat: mode === "drawing" ? -1 : 0 });
  }
  if (mode !== "result" || !data) return true;
  asArray(data.coins).forEach((item, index) => {
    const coin = asRecord(item);
    const worth = asNumber(coin.points);
    const token = scene.add.circle(860, 150 + asNumber(coin.lane) * 70, 16, worth > 0 ? 0xe2b15a : 0x314037);
    token.setScale(0.4);
    layer.add(token);
    scene.tweens.add({
      targets: token,
      x: 280,
      scale: 1,
      duration: 800,
      delay: 180 + index * 120,
      ease: "Quad.easeIn",
      onComplete: () => {
        if (worth > 0) sparks(scene, layer, 280, token.y);
      },
    });
  });
  return true;
}

function paintBottles(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "wood");
  layer.add(scene.add.rectangle(480, 360, 700, 16, 0x6b3d22));
  const items = data ? asArray(data.bottles) : [0, 1, 2, 3].map(() => ({ bonus: false, points: 0, delay: 0 }));
  items.forEach((item, index) => {
    const bottle = asRecord(item);
    const sprite = bottleSprite(scene, Boolean(bottle.bonus));
    const x = 200 + index * 120;
    sprite.setPosition(x, mode === "result" ? 40 : 250);
    layer.add(sprite);
    if (mode !== "result") return;
    scene.tweens.add({
      targets: sprite,
      y: 250,
      duration: 480,
      delay: asNumber(bottle.delay) * 160,
      ease: "Bounce.easeOut",
      onComplete: () => {
        if (asNumber(bottle.points) > 0) {
          scene.tweens.add({ targets: sprite, angle: 18, yoyo: true, duration: 90, repeat: 2 });
          sparks(scene, layer, x, 280, 0xf3efe4);
        }
      },
    });
  });
  return true;
}

function paintMystery(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "night");
  const open = mode === "result";
  const chest = chestSprite(scene, open, data ? `${asNumber(data.prize)}x` : "");
  chest.setPosition(480, 280);
  layer.add(chest);
  if (mode === "drawing") {
    scene.tweens.add({ targets: chest, angle: 3, yoyo: true, repeat: -1, duration: 90 });
  }
  if (open) sparks(scene, layer, 480, 220);
  return true;
}

function paintCoin(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "felt");
  const face = data ? asString(data.face, "HEADS") : "HEADS";
  const coin = coinSprite(scene, mode === "result" ? face : "HEADS");
  coin.setPosition(480, 270);
  layer.add(coin);
  if (mode === "idle") return true;
  scene.tweens.add({
    targets: coin,
    scaleX: 0.06,
    duration: 130,
    yoyo: true,
    repeat: mode === "result" ? 5 : -1,
    onComplete: () => {
      coin.setScale(1);
      if (mode === "result" && data?.won === true) sparks(scene, layer, 480, 270);
    },
  });
  return true;
}

function paintBoxes(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "night");
  const rewards = data ? asNumbers(data.rewards) : [0, 0, 0, 0];
  const chosen = data ? asNumber(data.index, -1) : -1;
  rewards.forEach((reward, index) => {
    const open = mode === "result" && index === chosen;
    const chest = chestSprite(scene, open, `${reward}x`);
    chest.setPosition(200 + index * 180, 280);
    layer.add(chest);
    if (mode === "drawing") {
      scene.tweens.add({ targets: chest, y: 268, yoyo: true, duration: 180, delay: index * 80, repeat: -1 });
    }
    if (open) sparks(scene, layer, 200 + index * 180, 240);
  });
  return true;
}

function paintTiles(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, cells: string[], matches: Set<number>, mode: BoardMode) {
  backdrop(scene, layer, "felt");
  const columns = 3;
  cells.forEach((cell, index) => {
    const x = 250 + (index % columns) * 160;
    const y = 190 + Math.floor(index / columns) * 140;
    const showFace = mode === "result";
    const face = showFace ? symbolToken(scene, cell, matches.has(index)) : cardBack(scene);
    face.setPosition(x, y);
    if (mode === "result") face.setScale(1, 0.05);
    layer.add(face);
    if (mode !== "result") return;
    scene.tweens.add({
      targets: face,
      scaleY: 1,
      duration: 220,
      delay: index * 90,
      ease: "Back.easeOut",
      onComplete: () => {
        if (matches.has(index)) sparks(scene, layer, x, y);
      },
    });
  });
  return cells.length > 0;
}

function paintDrop(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "night");
  layer.add(scene.add.rectangle(480, 360, 560, 18, 0x314037));
  const gems = data ? asStrings(data.gems) : ["GOLD", "RUBY", "JADE", "BLUE"];
  gems.forEach((name, index) => {
    const gem = gemSprite(scene, name);
    const x = 200 + index * 100;
    gem.setPosition(x, mode === "result" ? 40 : 250);
    layer.add(gem);
    if (mode !== "result") return;
    scene.tweens.add({ targets: gem, y: 300, duration: 380, delay: index * 90, ease: "Bounce.easeOut" });
  });
  return true;
}

function paintBurst(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "night");
  const count = data ? asNumber(data.count) : 0;
  const hub = scene.add.circle(480, 270, 26, 0xe2b15a);
  layer.add(hub);
  for (let index = 0; index < 6; index += 1) {
    const angle = (index / 6) * Math.PI * 2;
    const live = mode === "result" && index < count;
    const orb = scene.add.circle(480, 270, 12, live || mode !== "result" ? 0xf0d59a : 0x314037);
    layer.add(orb);
    scene.tweens.add({
      targets: orb,
      x: 480 + Math.cos(angle) * 140,
      y: 270 + Math.sin(angle) * 100,
      duration: 500,
      ease: "Back.easeOut",
      yoyo: mode === "drawing" || live,
      repeat: mode === "drawing" ? -1 : 0,
      hold: 160,
    });
  }
  return true;
}

function paintCards(scene: Phaser.Scene, layer: Phaser.GameObjects.Container, data: Record<string, unknown> | null, mode: BoardMode) {
  backdrop(scene, layer, "felt");
  const player = data ? asRecord(data.player) : { rank: "A", suit: "spades" };
  const house = data ? asRecord(data.house) : { rank: "K", suit: "hearts" };
  const yours = cardSprite(scene, asString(player.rank, "A"), asString(player.suit, "spades"));
  const theirs = cardSprite(scene, asString(house.rank, "K"), asString(house.suit, "hearts"));
  yours.setPosition(mode === "result" ? -40 : 340, 270);
  theirs.setPosition(mode === "result" ? -40 : 620, 270);
  layer.add([yours, theirs]);
  layer.add(scene.add.text(340, 400, "You", { fontFamily: "Georgia, serif", fontSize: "16px", color: "#f3efe4" }).setOrigin(0.5));
  layer.add(scene.add.text(620, 400, "House", { fontFamily: "Georgia, serif", fontSize: "16px", color: "#f3efe4" }).setOrigin(0.5));
  if (mode !== "result") return true;
  scene.tweens.add({ targets: yours, x: 340, duration: 420, ease: "Cubic.easeOut" });
  scene.tweens.add({
    targets: theirs,
    x: 620,
    duration: 420,
    delay: 200,
    ease: "Cubic.easeOut",
    onComplete: () => {
      if (data?.outcome === "win") {
        yours.setY(246);
        sparks(scene, layer, 340, 220);
      }
    },
  });
  return true;
}

function ball(scene: Phaser.Scene, x: number, caption: string, value: string) {
  const group = scene.add.container(x, 270);
  group.add(scene.add.circle(0, 0, 54, 0xf3efe4).setStrokeStyle(4, 0xe2b15a));
  group.add(scene.add.text(0, -6, value, { fontFamily: "Georgia, serif", fontSize: "36px", color: "#1a1408" }).setOrigin(0.5));
  group.add(scene.add.text(0, 78, caption, { fontFamily: "Georgia, serif", fontSize: "16px", color: "#f3efe4" }).setOrigin(0.5));
  return group;
}

function placeholder(length: number) {
  return Array.from({ length }, () => "COIN");
}

function isWheel(kind: string) {
  return kind === "wheel" || kind === "jackpot" || kind === "fruit" || kind === "lucky" || kind === "spinner" || kind === "diamond";
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
