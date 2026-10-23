import Phaser from "phaser";
import { kindForSlug, renderBoard } from "@/game/boards";
import { sparks } from "@/game/art";

export type RoundView = {
  title: string;
  winAmount: number;
  betAmount: number;
  multiplier: number;
  presentation: Record<string, unknown>;
};

export type StagePhase = "idle" | "drawing" | "result";

export type StageState = {
  phase: StagePhase;
  gameName: string;
  slug: string;
  round: RoundView | null;
};

export type StageHandle = {
  show: (state: StageState) => void;
  destroy: () => void;
};

export function mountStage(parent: HTMLElement): StageHandle {
  const scene = new TableScene();
  const game = new Phaser.Game({
    type: Phaser.AUTO,
    parent,
    width: 960,
    height: 540,
    backgroundColor: 0x0c1410,
    scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
    scene,
  });
  return {
    show: (state) => scene.show(state),
    destroy: () => game.destroy(true),
  };
}

class TableScene extends Phaser.Scene {
  private layer: Phaser.GameObjects.Container | null = null;
  private masks: Phaser.GameObjects.Graphics[] = [];
  private queued: StageState | null = null;
  private ready = false;
  private bulbs: Phaser.GameObjects.Arc[] = [];
  private title: Phaser.GameObjects.Text | null = null;

  constructor() {
    super("table");
  }

  create() {
    this.add.rectangle(480, 270, 960, 540, 0x070b09);
    this.add.rectangle(480, 270, 920, 500, 0x1a1408).setStrokeStyle(8, 0xc6a15a);
    this.add.rectangle(480, 270, 860, 430, 0x102018);
    this.title = this.add.text(480, 42, "", { fontFamily: "Georgia, serif", fontSize: "26px", color: "#f0d59a" }).setOrigin(0.5);
    for (let index = 0; index < 18; index += 1) {
      const bulb = this.add.circle(78 + index * 48, 78, 6, 0xe2b15a);
      this.bulbs.push(bulb);
    }
    this.ready = true;
    this.chaseLights();
    if (this.queued) {
      this.show(this.queued);
    }
  }

  private chaseLights() {
    this.bulbs.forEach((bulb, index) => {
      this.tweens.add({
        targets: bulb,
        alpha: 0.25,
        yoyo: true,
        repeat: -1,
        duration: 280,
        delay: index * 70,
      });
    });
  }

  show(state: StageState) {
    this.queued = state;
    if (!this.ready) {
      return;
    }
    this.tweens.killAll();
    this.chaseLights();
    this.layer?.destroy(true);
    this.masks.forEach((mask) => mask.destroy());
    this.masks = [];
    this.layer = this.add.container(0, 0);
    this.title?.setText(state.gameName);

    const kind = state.round ? String(state.round.presentation.kind ?? "") : kindForSlug(state.slug);
    const mode = state.phase === "result" && state.round ? "result" : state.phase === "drawing" ? "drawing" : "idle";
    const painted = renderBoard(this, this.layer, kind, state.round?.presentation ?? null, this.masks, mode);
    if (!painted) {
      this.prompt(this.layer, state.gameName, "Set a bet and play.");
    }
    if (state.round && mode === "result") {
      this.banner(this.layer, state.round);
      if (state.round.winAmount > 0) {
        this.cameras.main.shake(260, 0.007);
        sparks(this, this.layer, 480, 430, 0xf0d59a);
      }
    }
  }

  private prompt(layer: Phaser.GameObjects.Container, title: string, detail: string) {
    const heading = this.add
      .text(480, 230, title, { fontFamily: "Georgia, serif", fontSize: "36px", color: "#f0d59a" })
      .setOrigin(0.5);
    const body = this.add
      .text(480, 290, detail, {
        fontFamily: "Georgia, serif",
        fontSize: "18px",
        color: "#f3efe4",
        align: "center",
        wordWrap: { width: 640 },
      })
      .setOrigin(0.5);
    layer.add([heading, body]);
  }

  private banner(layer: Phaser.GameObjects.Container, round: RoundView) {
    const won = round.winAmount > 0;
    const plate = this.add.rectangle(480, 458, 520, 52, won ? 0x14382c : 0x241c16).setStrokeStyle(2, won ? 0x3ddc97 : 0xe2b15a);
    const label = won ? `${round.title}   +${round.winAmount}` : round.title || "No win";
    const text = this.add
      .text(480, 458, label, { fontFamily: "Georgia, serif", fontSize: "22px", color: won ? "#3ddc97" : "#f3efe4" })
      .setOrigin(0.5);
    plate.setScale(0.7);
    text.setScale(0.7);
    layer.add([plate, text]);
    this.tweens.add({ targets: [plate, text], scale: 1, delay: 600, duration: 320, ease: "Back.easeOut" });
  }
}
