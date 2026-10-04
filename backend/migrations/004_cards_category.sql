ALTER TABLE slot_games DROP CONSTRAINT IF EXISTS slot_games_category_check;
ALTER TABLE slot_games
  ADD CONSTRAINT slot_games_category_check
  CHECK (category IN ('SLOTS', 'SPIN', 'SCRATCH', 'REACTION', 'CHOICE', 'MATCH', 'BONUS', 'CARDS'));
