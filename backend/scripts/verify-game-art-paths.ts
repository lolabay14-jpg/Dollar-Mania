import fs from "node:fs";
import path from "node:path";

const root = path.resolve(__dirname, "../..");
const artPath = path.join(root, "game/scripts/ui/game_art.gd");
const imagesDir = path.join(root, "Images");
const art = fs.readFileSync(artPath, "utf8");
const images = new Set(fs.readdirSync(imagesDir).filter((name) => !name.endsWith(".import")));

const required = [
  "fruit-spin",
  "diamond-spin",
  "lucky-dollar",
  "scratch-mania",
  "lucky-wheel",
  "coin-flip",
  "treasure-box",
  "cash-match",
  "diamond-drop",
  "bonus-burst",
  "jackpot-wheel",
  "mystery-box",
  "dollar-rush",
  "fishing",
  "target-blast",
  "aeroplane-rush",
  "bottle-blast",
];

let failed = 0;
for (const slug of required) {
  const match = art.match(new RegExp(`"${slug}":\\s*"([^"]+)"`));
  const mapped = match?.[1] ?? "";
  const file = mapped.replace("res://Images/", "");
  const ok = Boolean(file) && images.has(file);
  console.log(`${ok ? "OK" : "MISS"} ${slug} -> ${file || "(none)"}`);
  if (!ok) failed += 1;
}

const screens = ["splash", "dashboard", "gameplay"];
for (const kind of screens) {
  const match = art.match(new RegExp(`"${kind}":\\s*"([^"]+)"`));
  const mapped = match?.[1] ?? "";
  const file = mapped.replace("res://Images/", "");
  const ok = Boolean(file) && images.has(file);
  console.log(`${ok ? "OK" : "MISS"} screen:${kind} -> ${file || "(none)"}`);
  if (!ok) failed += 1;
}

if (failed > 0) {
  process.exit(1);
}
console.log("All required game art paths resolve to existing Images files.");
