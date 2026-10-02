class_name GameConfig
extends RefCounted

## Shared rules for menus and the arcade round.
## Change GAME_CREDIT_COST here only — screens and gameplay both read this value.
## When a backend exists, the server can replace these defaults at startup.

const API_BASE_URL := "http://127.0.0.1:3000"
const GAME_CREDIT_COST := 10
const STARTING_CREDITS := 500
## Player level advances after this many recorded spins.
const SPINS_PER_LEVEL := 8
const ROUND_SECONDS := 45.0
const POINTS_PER_COIN := 10
const MAX_COINS := 6
const COIN_SPAWN_INTERVAL := 1.15
const OPENING_COINS := 4
## Fraction of the longer playfield side the player can cross in one second.
const MOVE_SPEED_RATIO := 0.62

const ACTIVE_PLAYER_ID := "player_alex"
const ADMIN_NAME := "Morgan Hale"
const ADMIN_TITLE := "Platform Admin"
