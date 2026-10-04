INSERT INTO slot_games (name, slug, description, difficulty, category, minimum_bet, maximum_bet, is_active)
VALUES
  ('Dice', 'dice', 'Roll two dice and land a winning total.', 'MEDIUM', 'CHOICE', 5, 100, true),
  ('Lucky Number', 'lucky-number', 'Pick a number and see what is drawn.', 'MEDIUM', 'MATCH', 5, 100, true)
ON CONFLICT (slug) DO NOTHING;
