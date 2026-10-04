ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users
  ADD CONSTRAINT users_role_check CHECK (role IN ('SUPER_ADMIN', 'ADMIN', 'PLAYER'));

INSERT INTO wallets (user_id, balance)
SELECT u.id, 0
FROM users u
WHERE NOT EXISTS (SELECT 1 FROM wallets w WHERE w.user_id = u.id);

ALTER TABLE credit_transactions
  ADD COLUMN IF NOT EXISTS request_id text;

CREATE UNIQUE INDEX IF NOT EXISTS credit_transactions_request_id_uid
  ON credit_transactions (request_id)
  WHERE request_id IS NOT NULL;
