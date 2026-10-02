ALTER TABLE credit_transactions
  ADD COLUMN IF NOT EXISTS transaction_type varchar(30);

UPDATE credit_transactions
SET transaction_type = 'BONUS'
WHERE transaction_type IS NULL;

ALTER TABLE credit_transactions
  ALTER COLUMN transaction_type SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'credit_transactions_type_check'
  ) THEN
    ALTER TABLE credit_transactions
      ADD CONSTRAINT credit_transactions_type_check
      CHECK (transaction_type IN ('ADMIN_ADD', 'ADMIN_REMOVE', 'GAME_BET', 'GAME_WIN', 'BONUS', 'REFUND'));
  END IF;
END $$;

ALTER TABLE slot_games
  ADD COLUMN IF NOT EXISTS difficulty varchar(20) DEFAULT 'EASY';

UPDATE slot_games
SET difficulty = 'EASY'
WHERE difficulty IS NULL OR difficulty = '';

ALTER TABLE slot_games
  ALTER COLUMN difficulty SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'slot_games_difficulty_check'
  ) THEN
    ALTER TABLE slot_games
      ADD CONSTRAINT slot_games_difficulty_check
      CHECK (difficulty IN ('EASY', 'MEDIUM', 'HARD'));
  END IF;
END $$;

ALTER TABLE game_sessions
  ADD COLUMN IF NOT EXISTS status varchar(20) DEFAULT 'ACTIVE';

UPDATE game_sessions
SET status = 'ACTIVE'
WHERE status IS NULL OR status = '';

ALTER TABLE game_sessions
  ALTER COLUMN status SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'game_sessions_status_check'
  ) THEN
    ALTER TABLE game_sessions
      ADD CONSTRAINT game_sessions_status_check
      CHECK (status IN ('ACTIVE', 'COMPLETED', 'ABANDONED'));
  END IF;
END $$;
