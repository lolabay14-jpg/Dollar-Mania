UPDATE slot_games
SET name = 'Fish Shooter',
    description = 'Aim an underwater cannon and shoot the fish.',
    updated_at = now()
WHERE slug = 'fishing';

UPDATE slot_games
SET name = 'Multiplier Rush',
    description = 'Pick a lane and ride the multiplier rush.',
    updated_at = now()
WHERE slug = 'dollar-rush';

INSERT INTO slot_games (name, slug, description, difficulty, category, minimum_bet, maximum_bet, is_active)
VALUES
  ('Diamond Spin', 'diamond-spin', 'A crystal wheel of gems and diamonds.', 'MEDIUM', 'SPIN', 5, 200, true),
  ('Mystery Box', 'mystery-box', 'Open one sealed chest and reveal the prize.', 'EASY', 'CHOICE', 5, 150, true),
  ('Target Blast', 'target-blast', 'An arcade gallery. Hit the targets before they fade.', 'MEDIUM', 'REACTION', 5, 200, true)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  difficulty = EXCLUDED.difficulty,
  category = EXCLUDED.category,
  minimum_bet = EXCLUDED.minimum_bet,
  maximum_bet = EXCLUDED.maximum_bet,
  is_active = true,
  updated_at = now();
