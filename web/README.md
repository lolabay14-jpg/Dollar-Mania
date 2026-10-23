# Dollar Mania web

Next.js dashboard and games for the existing Express API in `backend/`. The Godot client stays in the repo and is not used by this app.

## Run

1. Start the API from `backend/` (`npm run dev`, port 3000).
2. Copy `.env.example` to `.env.local` if it is not already there.
3. From `web/`, run `npm run dev`.
4. Open http://localhost:3001 and sign in with an existing player, admin, or super-admin account.

Player pages cover the wallet, history, credit requests, and the game floor. Admin pages cover players, credits, game settings, requests, and activity. Super-admin pages also cover staff, per-player game access, and ledgers.

Play results come from `POST /api/games/:slug/spin`. Phaser only animates the `presentation` the API returns.
