ALTER TABLE users
  ADD COLUMN IF NOT EXISTS game_mode varchar(20) NOT NULL DEFAULT 'MEDIUM';

DO $$
BEGIN
  ALTER TABLE users
    ADD CONSTRAINT users_game_mode_check CHECK (game_mode IN ('EASY', 'MEDIUM', 'HARD'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
