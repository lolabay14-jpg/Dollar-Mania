CREATE TABLE IF NOT EXISTS player_game_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  slot_game_id uuid NOT NULL,
  profile varchar(10) NOT NULL,
  parameters jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid,
  CONSTRAINT player_game_profiles_user_fk FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT player_game_profiles_game_fk FOREIGN KEY (slot_game_id) REFERENCES slot_games (id),
  CONSTRAINT player_game_profiles_admin_fk FOREIGN KEY (updated_by) REFERENCES users (id),
  CONSTRAINT player_game_profiles_profile_check CHECK (profile IN ('EASY', 'MEDIUM', 'HARD', 'DEFAULT')),
  CONSTRAINT player_game_profiles_user_game_uid UNIQUE (user_id, slot_game_id)
);

CREATE INDEX IF NOT EXISTS player_game_profiles_user_idx ON player_game_profiles (user_id);
