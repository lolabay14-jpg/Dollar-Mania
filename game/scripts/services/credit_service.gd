extends Node

## Local stand-in for the future credits API.
## Menus and the game should call this service instead of storing balances themselves.
## Replacing the bodies of these methods with network calls should not change the screens.

signal state_changed

var _players: Array[Dictionary] = []
var _transactions: Array[Dictionary] = []
var _history_by_player: Dictionary = {}
var _next_transaction_id := 1


func _ready() -> void:
	_seed_mock_data()


func get_active_player_id() -> String:
	return GameConfig.ACTIVE_PLAYER_ID


func get_active_player() -> Dictionary:
	return get_player(get_active_player_id())


func get_player(player_id: String) -> Dictionary:
	for player in _players:
		if str(player["id"]) == player_id:
			return player.duplicate()
	return {}


func get_players() -> Array:
	var copy: Array = []
	for player in _players:
		copy.append(player.duplicate())
	return copy


func get_balance(player_id: String) -> int:
	return int(get_player(player_id).get("credits", 0))


func get_total_players() -> int:
	return _players.size()


func get_total_credits() -> int:
	var total := 0
	for player in _players:
		total += int(player["credits"])
	return total


func can_afford_game(player_id: String) -> bool:
	return get_balance(player_id) >= GameConfig.GAME_CREDIT_COST


func spend_for_game(player_id: String) -> bool:
	return _apply_delta(player_id, -GameConfig.GAME_CREDIT_COST, "play", "Game entry")


func refund_game_entry(player_id: String) -> bool:
	return _apply_delta(player_id, GameConfig.GAME_CREDIT_COST, "refund", "Game entry refunded")


func add_credits(player_id: String, amount: int) -> String:
	if amount <= 0:
		return "Enter a credit amount greater than 0."
	if not _apply_delta(player_id, amount, "add", "Admin added credits"):
		return "That player could not be found."
	return ""


func remove_credits(player_id: String, amount: int) -> String:
	if amount <= 0:
		return "Enter a credit amount greater than 0."
	if get_balance(player_id) < amount:
		return "That player does not have enough credits."
	if not _apply_delta(player_id, -amount, "remove", "Admin removed credits"):
		return "That player could not be found."
	return ""


## Slot flow: place_bet, resolve the spin, then award_win if needed.
## These are the calls to swap for a backend later.
func place_bet(player_id: String, amount: int) -> String:
	if amount <= 0:
		return "Choose a bet greater than 0."
	if get_balance(player_id) < amount:
		return "Insufficient credits"
	if not _apply_delta(player_id, -amount, "bet", "Slot bet"):
		return "Could not place the bet."
	return ""


func award_win(player_id: String, amount: int, note: String) -> String:
	if amount <= 0:
		return ""
	if not _apply_delta(player_id, amount, "win", note):
		return "Could not add winnings."
	return ""


func record_round(player_id: String, game_name: String, bet: int, payout: int, title: String) -> void:
	_bump(player_id, "spins", 1)
	if payout > 0:
		_bump(player_id, "wins", 1)
	else:
		_bump(player_id, "losses", 1)
	if not _history_by_player.has(player_id):
		_history_by_player[player_id] = []
	var history: Array = _history_by_player[player_id]
	history.push_front({
		"game": game_name,
		"bet": bet,
		"payout": payout,
		"title": title,
		"at": _clock(),
	})
	state_changed.emit()


func get_level(player_id: String) -> int:
	var spins := int(get_player(player_id).get("spins", 0))
	var completed_levels := int(float(spins) / float(GameConfig.SPINS_PER_LEVEL))
	return 1 + completed_levels


func get_level_progress(player_id: String) -> float:
	var spins := int(get_player(player_id).get("spins", 0))
	return float(spins % GameConfig.SPINS_PER_LEVEL) / float(GameConfig.SPINS_PER_LEVEL)


func get_recent_transactions(limit: int = 12) -> Array:
	var recent: Array = []
	var count := mini(limit, _transactions.size())
	for index in count:
		recent.append((_transactions[index] as Dictionary).duplicate())
	return recent


func record_game_result(player_id: String, score: int, credits_used: int) -> void:
	if not _history_by_player.has(player_id):
		_history_by_player[player_id] = []
	var history: Array = _history_by_player[player_id]
	history.push_front({
		"score": score,
		"credits_used": credits_used,
		"at": _clock(),
	})
	state_changed.emit()


func get_game_history(player_id: String) -> Array:
	if not _history_by_player.has(player_id):
		return []
	var copy: Array = []
	for entry in _history_by_player[player_id]:
		copy.append((entry as Dictionary).duplicate())
	return copy


func _apply_delta(player_id: String, delta: int, kind: String, note: String) -> bool:
	for index in _players.size():
		var player := _players[index]
		if str(player["id"]) != player_id:
			continue
		var next_balance := int(player["credits"]) + delta
		if next_balance < 0:
			return false
		player["credits"] = next_balance
		_players[index] = player
		_transactions.push_front({
			"id": "tx_%d" % _next_transaction_id,
			"player_id": player_id,
			"player_name": str(player["name"]),
			"amount": delta,
			"kind": kind,
			"note": note,
			"at": _clock(),
		})
		_next_transaction_id += 1
		state_changed.emit()
		return true
	return false


func _seed_mock_data() -> void:
	# The signed-in player always starts from STARTING_CREDITS.
	# The other rows are sample accounts so admin tools have something to edit.
	_players = [
		{"id": GameConfig.ACTIVE_PLAYER_ID, "name": "Alex Rivera", "credits": GameConfig.STARTING_CREDITS, "tag": "Collector", "spins": 0, "wins": 0, "losses": 0},
		{"id": "player_jordan", "name": "Jordan Lee", "credits": 250, "tag": "Regular", "spins": 14, "wins": 4, "losses": 10},
		{"id": "player_sam", "name": "Sam Patel", "credits": 80, "tag": "New", "spins": 6, "wins": 1, "losses": 5},
		{"id": "player_riley", "name": "Riley Chen", "credits": 1400, "tag": "High roller", "spins": 40, "wins": 11, "losses": 29},
		{"id": "player_casey", "name": "Casey Brooks", "credits": 5, "tag": "Low balance", "spins": 3, "wins": 0, "losses": 3},
	]
	_transactions.clear()
	_next_transaction_id = 1
	for player in _players:
		_transactions.append({
			"id": "tx_%d" % _next_transaction_id,
			"player_id": str(player["id"]),
			"player_name": str(player["name"]),
			"amount": int(player["credits"]),
			"kind": "grant",
			"note": "Starting balance",
			"at": "Start",
		})
		_next_transaction_id += 1
	_transactions.reverse()


func _bump(player_id: String, key: String, delta: int) -> void:
	for index in _players.size():
		if str(_players[index]["id"]) != player_id:
			continue
		_players[index][key] = int(_players[index].get(key, 0)) + delta
		return


func _clock() -> String:
	return Time.get_time_string_from_system()
