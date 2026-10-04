CREATE TABLE IF NOT EXISTS platform_settings (
  key text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO platform_settings (key, value)
VALUES ('game_mode', 'MEDIUM')
ON CONFLICT (key) DO NOTHING;

ALTER TABLE slot_games DROP CONSTRAINT IF EXISTS slot_games_category_check;
ALTER TABLE slot_games
  ADD CONSTRAINT slot_games_category_check
  CHECK (category IN ('SLOTS', 'SPIN', 'SCRATCH', 'REACTION', 'CHOICE', 'MATCH', 'BONUS', 'CARDS', 'FISHING'));

INSERT INTO slot_games (name, slug, description, difficulty, category, minimum_bet, maximum_bet, is_active)
VALUES
  ('Fruit Spin', 'fruit-spin', 'Spin a fruit wheel and land on a prize.', 'MEDIUM', 'SPIN', 5, 100, true),
  ('Lucky Wheel', 'lucky-wheel', 'A prize wheel with coins, symbols, and multipliers.', 'MEDIUM', 'SPIN', 5, 200, true),
  ('Prize Spinner', 'prize-spinner', 'A glowing spinner that settles on a reward.', 'MEDIUM', 'SPIN', 5, 150, true),
  ('Fishing', 'fishing', 'Cast a line and see what the water brings in.', 'MEDIUM', 'FISHING', 5, 100, true)
ON CONFLICT (slug) DO NOTHING;
