extends Node

## HTTP client for the Dollar Mania API.
## The server owns accounts, wallets, and spin results.

var _token := ""
var _user: Dictionary = {}
signal _refresh_games_requested

var games_cache: Array = []
var balance_cache := -1.0
var _refreshing := false

const _SESSION_PATH := "user://session.cfg"


func _ready() -> void:
	_refresh_games_requested.connect(_refresh_games)
	_load_session()


func is_logged_in() -> bool:
	return _token != ""


func role() -> String:
	return str(_user.get("role", ""))


func username() -> String:
	return str(_user.get("username", ""))


func logout() -> void:
	_token = ""
	_user = {}
	games_cache = []
	balance_cache = -1.0
	_refreshing = false
	_clear_session()


func register(username_value: String, email: String, password: String, confirm_password: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/api/auth/register", {
		"username": username_value,
		"email": email,
		"password": password,
		"confirmPassword": confirm_password,
	}, false)


func login(username_value: String, password: String) -> Dictionary:
	var response := await _request(HTTPClient.METHOD_POST, "/api/auth/login", {
		"username": username_value,
		"password": password,
	}, false)
	if response.ok:
		var data: Dictionary = response.data
		_token = str(data.get("token", ""))
		var user = data.get("user", {})
		_user = user if user is Dictionary else {}
		_save_session()
	return response


func get_current_user() -> Dictionary:
	var response := await _request(HTTPClient.METHOD_GET, "/api/auth/me")
	if response.ok:
		var user = response.data.get("user", {})
		if user is Dictionary:
			_user = user
	return response


func get_player_profile() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/player/profile")


func get_wallet() -> Dictionary:
	var response := await _request(HTTPClient.METHOD_GET, "/api/player/wallet")
	if response.ok:
		balance_cache = float(response.data.get("balance", balance_cache))
	return response


func get_transactions() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/player/transactions")


func get_spin_history() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/player/spins")


func get_slot_games() -> Dictionary:
	if not games_cache.is_empty():
		if not _refreshing:
			_refreshing = true
			_refresh_games_requested.emit()
		return {"ok": true, "status": 200, "data": {"games": games_cache}, "error": ""}
	return await _refresh_games()


func _refresh_games() -> Dictionary:
	var response := await _request(HTTPClient.METHOD_GET, "/api/player/games")
	_refreshing = false
	if response.ok:
		var games = response.data.get("games", [])
		if games is Array:
			games_cache = games
	return response


func request_credits(amount: int) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/api/player/credit-requests", {"amount": amount})


func my_credit_requests() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/player/credit-requests")


func admin_credit_requests() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/credit-requests")


func admin_review_request(request_id: String, action: String) -> Dictionary:
	return await _request(
		HTTPClient.METHOD_POST,
		"/api/admin/credit-requests/%s/review" % request_id.uri_encode(),
		{"action": action}
	)


func spin(game_id: String, bet_amount: int, choice: Variant = null, request_id := "") -> Dictionary:
	var body := {"betAmount": bet_amount}
	if choice != null:
		body["choice"] = choice
	if request_id != "":
		body["requestId"] = request_id
	return await _request(
		HTTPClient.METHOD_POST,
		"/api/games/%s/spin" % game_id.uri_encode(),
		body
	)


func admin_users() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/users")


func admin_search_user(email: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/users/search?email=%s" % email.strip_edges().uri_encode())


func admin_find_player(email: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/users/player?email=%s" % email.strip_edges().uri_encode())


func admin_transactions() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/transactions")


func admin_activity() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/activity")


func admin_game_profiles(user_id: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/users/%s/game-profiles" % user_id.uri_encode())


func admin_set_game_profile(user_id: String, game_id: String, profile: String, parameters: Dictionary) -> Dictionary:
	return await _request(
		HTTPClient.METHOD_PUT,
		"/api/admin/users/%s/game-profiles/%s" % [user_id.uri_encode(), game_id.uri_encode()],
		{"profile": profile, "parameters": parameters}
	)


func admin_adjust_credits(user_id: String, amount: int, action: String) -> Dictionary:
	return await _request(
		HTTPClient.METHOD_POST,
		"/api/admin/users/%s/credits" % user_id.uri_encode(),
		{"amount": amount, "action": action}
	)


func _request(method: int, path: String, body: Variant = null, authenticated := true) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json"])
	var payload := ""
	if body != null:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(body)
	if authenticated:
		if _token == "":
			http.queue_free()
			return _fail(401, "Missing token")
		headers.append("Authorization: Bearer " + _token)
	var error := http.request(GameConfig.API_BASE_URL + path, headers, method, payload)
	if error != OK:
		http.queue_free()
		return _fail(0, "Could not reach the server.")
	var completed: Array = await http.request_completed
	if is_instance_valid(http):
		http.queue_free()
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS:
		return _fail(0, "Could not reach the server.")
	var code := int(completed[1])
	var parsed: Variant = JSON.parse_string(PackedByteArray(completed[3]).get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	if code >= 200 and code < 300:
		if data.has("balance"):
			balance_cache = float(data.get("balance", balance_cache))
		return {"ok": true, "status": code, "data": data, "error": ""}
	return _fail(code, str(data.get("error", "Request failed.")))


func _fail(code: int, message: String) -> Dictionary:
	return {"ok": false, "status": code, "data": {}, "error": message}


func _load_session() -> void:
	var file := ConfigFile.new()
	if file.load(_SESSION_PATH) != OK:
		return
	_token = str(file.get_value("auth", "token", ""))


func _save_session() -> void:
	if _token == "":
		_clear_session()
		return
	var file := ConfigFile.new()
	file.set_value("auth", "token", _token)
	file.save(_SESSION_PATH)


func _clear_session() -> void:
	if FileAccess.file_exists(_SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SESSION_PATH))
