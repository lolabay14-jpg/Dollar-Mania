CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username varchar(50) NOT NULL,
  email varchar(255),
  password_hash text NOT NULL,
  role varchar(20) NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_username_unique UNIQUE (username),
  CONSTRAINT users_email_unique UNIQUE (email),
  CONSTRAINT users_role_check CHECK (role IN ('ADMIN', 'PLAYER'))
);

CREATE TABLE IF NOT EXISTS player_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  display_name varchar(100),
  avatar text,
  level integer NOT NULL DEFAULT 1,
  experience integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT player_profiles_user_unique UNIQUE (user_id),
  CONSTRAINT player_profiles_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT player_profiles_level_check CHECK (level >= 1),
  CONSTRAINT player_profiles_experience_check CHECK (experience >= 0)
);

CREATE TABLE IF NOT EXISTS wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  balance numeric(18, 2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT wallets_user_unique UNIQUE (user_id),
  CONSTRAINT wallets_user_fk FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT wallets_balance_check CHECK (balance >= 0)
);

CREATE TABLE IF NOT EXISTS credit_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  amount numeric(18, 2) NOT NULL,
  balance_after numeric(18, 2) NOT NULL,
  transaction_type varchar(30) NOT NULL,
  description text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT credit_transactions_user_fk FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT credit_transactions_created_by_fk FOREIGN KEY (created_by) REFERENCES users (id),
  CONSTRAINT credit_transactions_type_check CHECK (
    transaction_type IN ('ADMIN_ADD', 'ADMIN_REMOVE', 'GAME_BET', 'GAME_WIN', 'BONUS', 'REFUND')
  ),
  CONSTRAINT credit_transactions_balance_check CHECK (balance_after >= 0)
);

CREATE INDEX IF NOT EXISTS credit_transactions_user_id_idx
  ON credit_transactions (user_id);
CREATE INDEX IF NOT EXISTS credit_transactions_created_at_idx
  ON credit_transactions (created_at);

CREATE TABLE IF NOT EXISTS slot_games (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(100) NOT NULL,
  slug varchar(100) NOT NULL,
  description text,
  difficulty varchar(20) NOT NULL,
  minimum_bet numeric(18, 2) NOT NULL,
  maximum_bet numeric(18, 2) NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT slot_games_slug_unique UNIQUE (slug),
  CONSTRAINT slot_games_difficulty_check CHECK (difficulty IN ('EASY', 'MEDIUM', 'HARD')),
  CONSTRAINT slot_games_bet_check CHECK (minimum_bet > 0 AND maximum_bet >= minimum_bet)
);

CREATE TABLE IF NOT EXISTS slot_spins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  slot_game_id uuid NOT NULL,
  bet_amount numeric(18, 2) NOT NULL,
  win_amount numeric(18, 2) NOT NULL DEFAULT 0,
  multiplier numeric(10, 2) NOT NULL DEFAULT 0,
  result jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT slot_spins_user_fk FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT slot_spins_game_fk FOREIGN KEY (slot_game_id) REFERENCES slot_games (id),
  CONSTRAINT slot_spins_amounts_check CHECK (bet_amount > 0 AND win_amount >= 0 AND multiplier >= 0)
);

CREATE INDEX IF NOT EXISTS slot_spins_user_created_idx
  ON slot_spins (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS game_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  slot_game_id uuid NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'ACTIVE',
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  score integer NOT NULL DEFAULT 0,
  credits_used numeric(18, 2) NOT NULL DEFAULT 0,
  credits_won numeric(18, 2) NOT NULL DEFAULT 0,
  CONSTRAINT game_sessions_user_fk FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT game_sessions_game_fk FOREIGN KEY (slot_game_id) REFERENCES slot_games (id),
  CONSTRAINT game_sessions_status_check CHECK (status IN ('ACTIVE', 'COMPLETED', 'ABANDONED')),
  CONSTRAINT game_sessions_amounts_check CHECK (score >= 0 AND credits_used >= 0 AND credits_won >= 0)
);

CREATE TABLE IF NOT EXISTS admin_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id uuid NOT NULL,
  target_user_id uuid,
  action varchar(50) NOT NULL,
  amount numeric(18, 2),
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT admin_activity_admin_fk FOREIGN KEY (admin_user_id) REFERENCES users (id),
  CONSTRAINT admin_activity_target_fk FOREIGN KEY (target_user_id) REFERENCES users (id)
);

CREATE INDEX IF NOT EXISTS admin_activity_created_idx
  ON admin_activity (created_at DESC);
