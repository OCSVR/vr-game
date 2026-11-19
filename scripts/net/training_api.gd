extends Node
## Talks to the team's Flask backend (OCSVR/ocs_backend, api/training_api.py):
##
##   POST /api/authenticate     {uid, password}  -> JWT (cookie jwt_python_flask)
##   POST /api/sessions/start   {module, device} -> {session_id, ...}
##   POST /api/sessions/complete {session_id?, module, attempts, duration_s, score, device}
##   GET  /api/learners/<uid>/progress -> totals, one line per mission, recent sessions
##
## Godot's HTTPRequest doesn't keep cookies, so the JWT is read out of the
## login response's Set-Cookie header and sent back as `Authorization: Bearer`,
## which the backend also accepts.
##
## Every request goes through `transport`, a Callable that tests can replace
## with a fake server. It takes (method, url, headers, body) and returns
## {code, headers, body}; code 0 means the server couldn't be reached.

## e.g. "http://localhost:8587" on the laptop. The Quest reaches the laptop's
## backend at the same address after `adb reverse tcp:8587 tcp:8587`.
var base_url := ""
## The signed-in account's JWT, empty when signed out.
var token := ""
var transport: Callable = _http_transport


## Signs in and keeps the token. Returns "" on success, or why it failed.
func sign_in(uid: String, password: String) -> String:
	var reply: Dictionary = await _send(HTTPClient.METHOD_POST, "/api/authenticate", {"uid": uid, "password": password}, false)
	if reply.code != 200:
		return _why(reply, "Sign-in failed")
	token = _jwt_from(reply.headers)
	return "" if token != "" else "Sign-in worked but the server sent no login cookie"


## Starts a session for the signed-in learner. Returns the server's session
## ({session_id, ...}), or {"error": why}.
func start_session(module: String, device: String) -> Dictionary:
	return _result(await _send(HTTPClient.METHOD_POST, "/api/sessions/start", {"module": module, "device": device}))


## Saves a result. With a session_id from start_session() a repeat is safe: the
## server returns the saved result. Returns the session, or {"error": why}.
func complete_session(result: Dictionary) -> Dictionary:
	return _result(await _send(HTTPClient.METHOD_POST, "/api/sessions/complete", result))


## A learner's progress report. Learners get their own; Teachers and Admins anyone's.
func get_progress(uid: String) -> Dictionary:
	return _result(await _send(HTTPClient.METHOD_GET, "/api/learners/%s/progress" % uid.uri_encode(), {}))


func _send(method: int, path: String, body: Dictionary, signed := true) -> Dictionary:
	var headers := PackedStringArray(["Accept: application/json"])
	var payload := ""
	if method != HTTPClient.METHOD_GET:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(body)
	if signed and token != "":
		headers.append("Authorization: Bearer " + token)
	return await transport.call(method, base_url.trim_suffix("/") + path, headers, payload)


func _result(reply: Dictionary) -> Dictionary:
	if reply.code in [200, 201] and typeof(reply.body) == TYPE_DICTIONARY:
		return reply.body
	return {"error": _why(reply, "Request failed"), "code": reply.code}


func _why(reply: Dictionary, what: String) -> String:
	if reply.code == 0:
		return "Can't reach the server at %s" % base_url
	var message = reply.body.get("message") if typeof(reply.body) == TYPE_DICTIONARY else null
	return "%s (HTTP %d)%s" % [what, reply.code, ": " + str(message) if message else ""]


## The JWT from a Set-Cookie header (any cookie whose name starts with "jwt").
static func _jwt_from(headers: PackedStringArray) -> String:
	for header in headers:
		if not header.to_lower().begins_with("set-cookie:"):
			continue
		var cookie := header.substr(header.find(":") + 1).strip_edges().get_slice(";", 0)
		var name := cookie.get_slice("=", 0)
		if name.begins_with("jwt"):
			return cookie.substr(name.length() + 1)
	return ""


## The real transport: one HTTPRequest per call, freed afterwards.
func _http_transport(method: int, url: String, headers: PackedStringArray, body: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	var error := http.request(url, headers, method, body)
	if error != OK:
		http.queue_free()
		return {"code": 0, "headers": PackedStringArray(), "body": null}
	var done: Array = await http.request_completed
	http.queue_free()
	var result: int = done[0]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "headers": PackedStringArray(), "body": null}
	return {"code": done[1], "headers": done[2], "body": JSON.parse_string(done[3].get_string_from_utf8())}
