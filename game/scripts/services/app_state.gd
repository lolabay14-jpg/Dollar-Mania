extends Node

const SCENE_LOGIN := "res://game/scenes/login_screen.tscn"
const SCENE_SIGNUP := "res://game/scenes/signup_screen.tscn"
const SCENE_SPLASH := "res://game/scenes/splash_screen.tscn"
const SCENE_MAIN := "res://game/scenes/main_menu.tscn"
const SCENE_SLOTS := "res://game/scenes/slot_games.tscn"
const SCENE_MACHINE := "res://game/scenes/game_stage.tscn"
const SCENE_SETTINGS := "res://game/scenes/settings_screen.tscn"
const SCENE_PLAYER := "res://game/scenes/player_dashboard.tscn"
const SCENE_ADMIN := "res://game/scenes/admin_dashboard.tscn"
const SCENE_GAME := "res://game/scenes/main_game.tscn"
const SCENE_GAME_OVER := "res://game/scenes/game_over.tscn"

var sound_enabled := true
var music_enabled := true
var last_score := 0
var last_credits_used := 0
var last_remaining_credits := 0
var entry_paid := false
var selected_slot_id := "lucky-dollar"
var selected_game: Dictionary = {}
var login_notice := ""
var _changing := false


func _ready() -> void:
	GameInput.ensure_actions()
	ScreenLayout.install()


func go_start() -> void:
	_change(SCENE_LOGIN)


func go_login() -> void:
	_change(SCENE_LOGIN)


func go_signup() -> void:
	_change(SCENE_SIGNUP)


func go_main() -> void:
	_change(SCENE_MAIN)


func go_slots() -> void:
	_change(SCENE_SLOTS)


func go_machine() -> void:
	_change(SCENE_MACHINE)


func go_settings() -> void:
	_change(SCENE_SETTINGS)


func go_player() -> void:
	_change(SCENE_PLAYER)


func go_admin() -> void:
	_change(SCENE_ADMIN)


func _change(path: String) -> void:
	if _changing:
		return
	_changing = true
	if SceneTransition:
		await SceneTransition.cover()
	var error := _go(path)
	if error == OK:
		await get_tree().process_frame
	if SceneTransition:
		await SceneTransition.reveal()
	_changing = false


## Charges GAME_CREDIT_COST once, then opens the arcade scene.
## Returns an empty string on success, or a message the UI can show.
func try_start_game() -> String:
	var player_id := CreditService.get_active_player_id()
	if not CreditService.can_afford_game(player_id):
		return "Not enough credits. A game costs %d credits." % GameConfig.GAME_CREDIT_COST
	if not CreditService.spend_for_game(player_id):
		return "Could not reserve credits for this game."
	entry_paid = true
	last_credits_used = GameConfig.GAME_CREDIT_COST
	var error := _go(SCENE_GAME)
	if error != OK:
		entry_paid = false
		CreditService.refund_game_entry(player_id)
		last_credits_used = 0
		return "Could not open the game."
	return ""


func consume_paid_entry() -> bool:
	if not entry_paid:
		return false
	entry_paid = false
	return true


func finish_game(score: int) -> void:
	var player_id := CreditService.get_active_player_id()
	last_score = score
	last_remaining_credits = CreditService.get_balance(player_id)
	CreditService.record_game_result(player_id, score, last_credits_used)
	_go(SCENE_GAME_OVER)


func _go(path: String) -> Error:
	get_tree().paused = false
	GameInput.release_movement()
	var outgoing := get_tree().current_scene
	var error := get_tree().change_scene_to_file(path)
	if error == OK and outgoing and outgoing.scene_file_path != path:
		outgoing.process_mode = Node.PROCESS_MODE_DISABLED
	return error
