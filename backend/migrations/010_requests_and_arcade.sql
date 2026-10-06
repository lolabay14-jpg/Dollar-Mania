ALTER TABLE credit_requests
  ADD COLUMN IF NOT EXISTS request_note text;

INSERT INTO slot_games (name, slug, description, difficulty, category, minimum_bet, maximum_bet, is_active)
VALUES
  ('Aeroplane Rush', 'aeroplane-rush', 'Fly the plane, dodge clouds, and collect coins.', 'MEDIUM', 'REACTION', 5, 200, true),
  ('Bottle Blast', 'bottle-blast', 'Aim an arcade launcher and break the bottles.', 'MEDIUM', 'REACTION', 5, 200, true)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  difficulty = EXCLUDED.difficulty,
  category = EXCLUDED.category,
  minimum_bet = EXCLUDED.minimum_bet,
  maximum_bet = EXCLUDED.maximum_bet,
  is_active = true,
  updated_at = now();
