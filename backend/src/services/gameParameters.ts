import { AppError } from "../errors";

export const PROFILE_LEVELS = ["EASY", "MEDIUM", "HARD", "DEFAULT"] as const;

export type ProfileLevel = (typeof PROFILE_LEVELS)[number];

export type ParameterDef = {
  key: string;
  label: string;
  min: number;
  max: number;
  step: number;
  defaultValue: number;
};

const rewardScale: ParameterDef = {
  key: "rewardScale",
  label: "Reward scale",
  min: 0.5,
  max: 2,
  step: 0.05,
  defaultValue: 1,
};

const extras: Record<string, ParameterDef[]> = {
  "lucky-dollar": [
    { key: "lineBoost", label: "Line boost", min: 0, max: 20, step: 1, defaultValue: 0 },
  ],
  "golden-fortune": [
    { key: "lineBoost", label: "Line boost", min: 0, max: 20, step: 1, defaultValue: 0 },
  ],
  "dollar-rush": [
    { key: "hitChance", label: "Hit chance", min: 10, max: 60, step: 1, defaultValue: 30 },
  ],
  "scratch-mania": [
    { key: "matchBoost", label: "Match boost", min: 0, max: 25, step: 1, defaultValue: 0 },
  ],
  "lucky-spin": [
    { key: "prizeBias", label: "Prize bias", min: 0, max: 20, step: 1, defaultValue: 0 },
  ],
  "coin-flip": [
    { key: "winChance", label: "Win chance", min: 35, max: 60, step: 1, defaultValue: 47 },
  ],
  "treasure-box": [
    { key: "emptyWeight", label: "Empty weight", min: 30, max: 80, step: 1, defaultValue: 60 },
  ],
  "cash-match": [
    { key: "pairBoost", label: "Pair boost", min: 0, max: 20, step: 1, defaultValue: 0 },
  ],
  "diamond-drop": [
    { key: "comboBoost", label: "Combo boost", min: 0, max: 20, step: 1, defaultValue: 0 },
  ],
  "bonus-burst": [
    { key: "collectBoost", label: "Collect boost", min: 0, max: 20, step: 1, defaultValue: 0 },
  ],
  "jackpot-wheel": [
    { key: "prizeBias", label: "Prize bias", min: 0, max: 15, step: 1, defaultValue: 0 },
  ],
  "fruit-spin": [
    { key: "prizeBias", label: "Prize bias", min: 0, max: 12, step: 1, defaultValue: 0 },
  ],
  "diamond-spin": [
    { key: "prizeBias", label: "Prize bias", min: 0, max: 12, step: 1, defaultValue: 0 },
  ],
  "mystery-box": [
    { key: "prizeBias", label: "Prize bias", min: 0, max: 12, step: 1, defaultValue: 0 },
  ],
  "lucky-wheel": [
    { key: "prizeBias", label: "Prize bias", min: 0, max: 12, step: 1, defaultValue: 0 },
  ],
  "prize-spinner": [
    { key: "prizeBias", label: "Prize bias", min: 0, max: 12, step: 1, defaultValue: 0 },
  ],
};

export function parametersForSlug(slug: string): ParameterDef[] {
  return [rewardScale, ...(extras[slug] ?? [])];
}

export function defaultParameters(slug: string): Record<string, number> {
  const values: Record<string, number> = {};
  for (const definition of parametersForSlug(slug)) {
    values[definition.key] = definition.defaultValue;
  }
  return values;
}

export function clampParameter(slug: string, key: string, value: unknown): number {
  const definition = parametersForSlug(slug).find((item) => item.key === key);
  if (!definition) {
    return 0;
  }
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return definition.defaultValue;
  }
  return Math.min(definition.max, Math.max(definition.min, value));
}

export function readParameters(slug: string, input: unknown): Record<string, number> {
  if (input === undefined) {
    return defaultParameters(slug);
  }
  if (typeof input !== "object" || input === null || Array.isArray(input)) {
    throw new AppError(400, "Game parameters must be an object.");
  }
  const source = input as Record<string, unknown>;
  const definitions = parametersForSlug(slug);
  const allowed = new Set(definitions.map((definition) => definition.key));
  for (const key of Object.keys(source)) {
    if (!allowed.has(key)) {
      throw new AppError(400, "That parameter is not available for this game.");
    }
  }
  const values: Record<string, number> = {};
  for (const definition of definitions) {
    const raw = source[definition.key];
    if (raw === undefined) {
      values[definition.key] = definition.defaultValue;
      continue;
    }
    if (typeof raw !== "number" || !Number.isFinite(raw)) {
      throw new AppError(400, `${definition.label} must be a number.`);
    }
    const steps = Math.round(raw / definition.step);
    const snapped = Math.round(steps * definition.step * 1000) / 1000;
    if (Math.abs(snapped - raw) > 0.001 || snapped < definition.min || snapped > definition.max) {
      throw new AppError(400, `${definition.label} must be between ${definition.min} and ${definition.max}.`);
    }
    values[definition.key] = snapped;
  }
  return values;
}
