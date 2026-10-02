extends Node

## HTTP client for the Dollar Mania API.
## The server owns accounts, wallets, and spin results.

var _token := ""
var _user: Dictionary = {}

const _SESSION_PATH := "user://session.cfg"


func _ready() -> void:
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
	return await _request(HTTPClient.METHOD_GET, "/api/player/wallet")


func get_transactions() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/player/transactions")


func get_spin_history() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/player/spins")


func get_slot_games() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/player/games")


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


func admin_transactions() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/transactions")


func admin_activity() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/activity")


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
