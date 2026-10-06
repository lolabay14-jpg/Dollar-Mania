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


func login(username_value: String, password: String) -> Dictionary:
	var response := await _request(HTTPClient.METHOD_POST, "/api/auth/login", {
		"username": username_value,
		"password": password,
	}, false)
	if response.ok:
		var data: Dictionary = response.data
		_token = str(data.get("token", ""))
		var user_value: Variant = data.get("user", {})
		var user: Dictionary = user_value if user_value is Dictionary else {}
		_user = user
		if _token == "":
			_log_login_failure(int(response.get("status", 0)), "Login response did not include a session token.", int(response.get("transport", HTTPRequest.RESULT_SUCCESS)))
			return _fail(int(response.get("status", 0)), "Login response did not include a session token.")
		_save_session()
	else:
		_log_login_failure(
			int(response.get("status", 0)),
			str(response.get("body", response.get("error", ""))),
			int(response.get("transport", HTTPRequest.RESULT_SUCCESS))
		)
	return response


func get_current_user() -> Dictionary:
	var response := await _request(HTTPClient.METHOD_GET, "/api/auth/me")
	if response.ok:
		var user_value: Variant = response.data.get("user", {})
		if user_value is Dictionary:
			_user = user_value
	return response


func change_password(current_password: String, new_password: String, confirm_password: String) -> Dictionary:
	var response := await _request(HTTPClient.METHOD_POST, "/api/auth/change-password", {
		"currentPassword": current_password,
		"newPassword": new_password,
		"confirmPassword": confirm_password,
	})
	if response.ok:
		var token := str(response.data.get("token", ""))
		if token != "":
			_token = token
			_save_session()
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


func reload_slot_games() -> Dictionary:
	games_cache.clear()
	return await _refresh_games()


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
		var games_value: Variant = response.data.get("games", [])
		if games_value is Array:
			games_cache = games_value
	return response


func request_credits(amount: int, note := "") -> Dictionary:
	var body := {"amount": amount}
	if note.strip_edges() != "":
		body["note"] = note.strip_edges()
	return await _request(HTTPClient.METHOD_POST, "/api/player/credit-requests", body)


func admin_request_credits(amount: int, note := "") -> Dictionary:
	var body := {"amount": amount}
	if note.strip_edges() != "":
		body["note"] = note.strip_edges()
	return await _request(HTTPClient.METHOD_POST, "/api/admin/credit-requests", body)


func admin_own_credit_requests() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/credit-requests/own")


func my_credit_requests() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/player/credit-requests")


func admin_credit_requests(status := "ALL") -> Dictionary:
	var path := "/api/admin/credit-requests"
	if status != "" and status != "ALL":
		path = "%s?status=%s" % [path, status.uri_encode()]
	return await _request(HTTPClient.METHOD_GET, path)


func admin_pending_credit_count() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/credit-requests/pending-count")


func admin_review_request(request_id: String, action: String, note := "") -> Dictionary:
	var body := {"action": action}
	if note.strip_edges() != "":
		body["note"] = note.strip_edges()
	return await _request(
		HTTPClient.METHOD_POST,
		"/api/admin/credit-requests/%s/review" % request_id.uri_encode(),
		body
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


func admin_overview() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/overview")


func admin_games() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/games")


func admin_platform_settings() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/settings")


func admin_set_game_mode(mode: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_PUT, "/api/admin/settings/mode", {"gameMode": mode})


func admin_set_player_game_mode(user_id: String, mode: String) -> Dictionary:
	return await _request(
		HTTPClient.METHOD_PATCH,
		"/api/admin/users/%s/game-mode" % user_id.uri_encode(),
		{"gameMode": mode}
	)


func admin_set_game_active(game_id: String, active: bool) -> Dictionary:
	return await _request(HTTPClient.METHOD_PATCH, "/api/admin/games/%s" % game_id.uri_encode(), {"isActive": active})


func admin_plays() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/plays")


func admin_users() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/users")


func admin_create_player(
	username_value: String,
	email: String,
	password: String,
	confirm_password: String,
	starting_credits: int
) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/api/admin/users", {
		"username": username_value,
		"email": email,
		"password": password,
		"confirmPassword": confirm_password,
		"startingCredits": starting_credits,
		"role": "PLAYER",
	})


func admin_create_admin(username_value: String, email: String, password: String, confirm_password: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/api/admin/staff", {
		"username": username_value,
		"email": email,
		"password": password,
		"confirmPassword": confirm_password,
	})


func admin_set_staff_active(user_id: String, active: bool) -> Dictionary:
	return await _request(
		HTTPClient.METHOD_PATCH,
		"/api/admin/staff/%s/access" % user_id.uri_encode(),
		{"isActive": active}
	)


func admin_update_player(user_id: String, fields: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_PATCH, "/api/admin/users/%s" % user_id.uri_encode(), fields)


func admin_player_history(user_id: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/users/%s/history" % user_id.uri_encode())


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


func admin_search_game_access(query: String) -> Dictionary:
	return await _request(
		HTTPClient.METHOD_GET,
		"/api/admin/game-access/search?q=%s" % query.strip_edges().uri_encode()
	)


func admin_player_game_access(user_id: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/users/%s/game-access" % user_id.uri_encode())


func admin_set_player_game_access(user_id: String, game_id: String, enabled: bool) -> Dictionary:
	return await _request(
		HTTPClient.METHOD_PUT,
		"/api/admin/users/%s/game-access/%s" % [user_id.uri_encode(), game_id.uri_encode()],
		{"enabled": enabled}
	)


func admin_set_all_player_game_access(user_id: String, enabled: bool) -> Dictionary:
	return await _request(
		HTTPClient.METHOD_PUT,
		"/api/admin/users/%s/game-access" % user_id.uri_encode(),
		{"enabled": enabled}
	)


func admin_staff() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/staff")


func admin_ledger(user_id: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/api/admin/users/%s/ledger" % user_id.uri_encode())


func admin_adjust_credits(user_id: String, amount: int, action: String, note: String = "", request_id: String = "") -> Dictionary:
	var body := {"amount": amount, "action": action}
	if note != "":
		body["note"] = note
	if request_id != "":
		body["requestId"] = request_id
	return await _request(
		HTTPClient.METHOD_POST,
		"/api/admin/users/%s/credits" % user_id.uri_encode(),
		body
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
	var start_error := http.request(GameConfig.API_BASE_URL + path, headers, method, payload)
	if start_error != OK:
		http.queue_free()
		return _cannot_start(start_error)
	var completed: Array = await http.request_completed
	if is_instance_valid(http):
		http.queue_free()
	var result := _http_result(int(completed[0]))
	if result != HTTPRequest.RESULT_SUCCESS:
		return _fail(0, "Could not reach the server.", "", result)
	var code := int(completed[1])
	var raw_body := PackedByteArray(completed[3]).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw_body)
	var data: Dictionary = parsed if parsed is Dictionary else {}
	if code >= 200 and code < 300:
		if data.has("balance") and not data.has("senderBalance"):
			balance_cache = float(data.get("balance", balance_cache))
		return {"ok": true, "status": code, "data": data, "error": "", "body": "", "transport": result}
	return _fail(code, str(data.get("error", "Request failed.")), raw_body, result)


func _cannot_start(start_error: Error) -> Dictionary:
	var detail := "Could not reach the server. Request was not started (%s)." % error_string(start_error)
	return {
		"ok": false,
		"status": 0,
		"data": {},
		"error": "Could not reach the server.",
		"body": detail,
		"transport": int(start_error),
	}


func _fail(code: int, message: String, raw_body := "", result := HTTPRequest.RESULT_SUCCESS) -> Dictionary:
	return {
		"ok": false,
		"status": code,
		"data": {},
		"error": message,
		"body": _redact_secrets(raw_body if raw_body != "" else message),
		"transport": result,
	}


func _http_result(value: int) -> HTTPRequest.Result:
	match value:
		HTTPRequest.RESULT_SUCCESS:
			return HTTPRequest.RESULT_SUCCESS
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH
		HTTPRequest.RESULT_CANT_CONNECT:
			return HTTPRequest.RESULT_CANT_CONNECT
		HTTPRequest.RESULT_CANT_RESOLVE:
			return HTTPRequest.RESULT_CANT_RESOLVE
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return HTTPRequest.RESULT_CONNECTION_ERROR
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR
		HTTPRequest.RESULT_NO_RESPONSE:
			return HTTPRequest.RESULT_NO_RESPONSE
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED
		HTTPRequest.RESULT_REQUEST_FAILED:
			return HTTPRequest.RESULT_REQUEST_FAILED
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED
		HTTPRequest.RESULT_TIMEOUT:
			return HTTPRequest.RESULT_TIMEOUT
		_:
			return HTTPRequest.RESULT_REQUEST_FAILED


func _log_login_failure(status: int, raw_body: String, transport: int) -> void:
	var detail := _redact_secrets(raw_body)
	if transport != HTTPRequest.RESULT_SUCCESS:
		push_error("Login failed. HTTP status %d. Transport result %d. Response: %s" % [status, transport, detail])
		return
	push_error("Login failed. HTTP status %d. Response: %s" % [status, detail])


func _redact_secrets(text: String) -> String:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var copy: Dictionary = (parsed as Dictionary).duplicate(true)
		_strip_secrets(copy)
		return JSON.stringify(copy)
	var redacted := text
	var pieces := redacted.split(" ")
	for index in pieces.size():
		var piece := str(pieces[index])
		if piece.count(".") == 2 and piece.length() > 20:
			pieces[index] = "[redacted]"
	return " ".join(pieces)


func _strip_secrets(data: Dictionary) -> void:
	for key in data.keys():
		var name := str(key).to_lower()
		if name in ["password", "token", "access_token", "accesstoken", "authorization", "jwt", "secret", "password_hash"]:
			data[key] = "[redacted]"
		elif data[key] is Dictionary:
			_strip_secrets(data[key])


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
