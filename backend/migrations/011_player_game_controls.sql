CREATE TABLE IF NOT EXISTS player_game_controls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  game_id uuid NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid,
  CONSTRAINT player_game_controls_player_fk FOREIGN KEY (player_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT player_game_controls_game_fk FOREIGN KEY (game_id) REFERENCES slot_games (id) ON DELETE CASCADE,
  CONSTRAINT player_game_controls_admin_fk FOREIGN KEY (updated_by) REFERENCES users (id),
  CONSTRAINT player_game_controls_player_game_uid UNIQUE (player_id, game_id)
);

CREATE INDEX IF NOT EXISTS player_game_controls_player_idx ON player_game_controls (player_id);
CREATE INDEX IF NOT EXISTS player_game_controls_disabled_idx
  ON player_game_controls (player_id)
  WHERE enabled = false;
