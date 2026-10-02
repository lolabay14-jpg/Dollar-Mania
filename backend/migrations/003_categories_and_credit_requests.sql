ALTER TABLE slot_games
  ADD COLUMN IF NOT EXISTS category varchar(20) DEFAULT 'SLOTS';

UPDATE slot_games SET category = 'SLOTS' WHERE category IS NULL OR category = '';
UPDATE slot_games SET category = 'SLOTS' WHERE slug IN ('lucky-dollar', 'golden-fortune');
UPDATE slot_games SET category = 'REACTION' WHERE slug = 'dollar-rush';
UPDATE slot_games SET category = 'SCRATCH' WHERE slug = 'scratch-mania';
UPDATE slot_games SET category = 'SPIN' WHERE slug IN ('lucky-spin', 'jackpot-wheel');
UPDATE slot_games SET category = 'CHOICE' WHERE slug IN ('coin-flip', 'treasure-box');
UPDATE slot_games SET category = 'MATCH' WHERE slug IN ('cash-match', 'diamond-drop');
UPDATE slot_games SET category = 'BONUS' WHERE slug = 'bonus-burst';
UPDATE slot_games SET difficulty = 'MEDIUM' WHERE slug IN ('cash-match', 'bonus-burst');
UPDATE slot_games SET difficulty = 'HARD' WHERE slug = 'diamond-drop';

ALTER TABLE slot_games
  ALTER COLUMN category SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'slot_games_category_check'
  ) THEN
    ALTER TABLE slot_games
      ADD CONSTRAINT slot_games_category_check
      CHECK (category IN ('SLOTS', 'SPIN', 'SCRATCH', 'REACTION', 'CHOICE', 'MATCH', 'BONUS'));
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS credit_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  requested_amount numeric(18, 2) NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'PENDING',
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid,
  admin_note text,
  CONSTRAINT credit_requests_user_fk FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT credit_requests_reviewer_fk FOREIGN KEY (reviewed_by) REFERENCES users (id),
  CONSTRAINT credit_requests_amount_check CHECK (requested_amount > 0),
  CONSTRAINT credit_requests_status_check CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'))
);

CREATE INDEX IF NOT EXISTS credit_requests_user_id_idx ON credit_requests (user_id);
CREATE INDEX IF NOT EXISTS credit_requests_status_idx ON credit_requests (status);
CREATE UNIQUE INDEX IF NOT EXISTS credit_requests_one_pending_idx
  ON credit_requests (user_id)
  WHERE status = 'PENDING';
