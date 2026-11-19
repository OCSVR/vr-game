extends Node
## The ScoreReporter autoload (build-plan step 5): sends each finished mission
## to the Flask training API, so it shows up in GET /api/learners/<uid>/progress.
##
## When the TrainingManager starts a mission, this starts a session on the
## server; when the mission is completed, it completes that session with the
## score, time and attempts. Completing with a session_id is safe to retry (the
## server returns the saved result), so a dropped Wi-Fi request is retried.
## Practice missions aren't sent.
##
## Which server and account: environment variables first, then a config file
## that stays on this computer (never commit a password):
##
##   OCSVR_API_URL, OCSVR_UID, OCSVR_PASSWORD
##   user://ocsvr_api.cfg   [api] base_url=..., uid=..., password=...
##
## Use an activated account; the backend refuses inactive and guest accounts.

const TrainingApi := preload("res://scripts/net/training_api.gd")
const CONFIG_PATH := "user://ocsvr_api.cfg"
const DEFAULT_URL := "http://localhost:8587"

## Emitted after each report: ok, plus a line for the student.
signal report_finished(ok: bool, message: String)

var api: TrainingApi
var uid := ""
var password := ""
## Retry settings for completing a session.
var max_tries := 3
var retry_wait_s := 1.0
## The server session for the mission being played ("" if none).
var session_id := ""

var _manager: Node
var _starting := false
signal _start_done


func _ready() -> void:
	api = TrainingApi.new()
	api.name = "TrainingApi"
	add_child(api)
	load_settings()
	_manager = get_node_or_null("/root/TrainingManager")
	if _manager:
		_manager.mission_started.connect(_on_mission_started)
		_manager.module_completed.connect(_on_module_completed)


func load_settings() -> void:
	var file := ConfigFile.new()
	file.load(CONFIG_PATH)  # missing is fine: then only the environment counts
	api.base_url = _setting("OCSVR_API_URL", file, "base_url", DEFAULT_URL)
	uid = _setting("OCSVR_UID", file, "uid", "")
	password = _setting("OCSVR_PASSWORD", file, "password", "")


func is_configured() -> bool:
	return uid != "" and password != ""


## "quest" on the headset, "desktop" on a laptop.
static func device_name() -> String:
	return "quest" if OS.has_feature("android") else "desktop"


func _on_mission_started(module_id: String) -> void:
	session_id = ""
	if _is_practice() or not is_configured():
		return
	_starting = true
	if await _signed_in() == "":
		var session: Dictionary = await api.start_session(module_id, device_name())
		session_id = session.get("session_id", "")
	_starting = false
	_start_done.emit()


func _on_module_completed(module_id: String, score: int, duration_s: int) -> void:
	if _is_practice():
		return
	if not is_configured():
		report_finished.emit(false, "Score not saved: no account is set up on this computer.")
		return
	if _starting:
		await _start_done
	var problem := await _signed_in()
	if problem != "":
		report_finished.emit(false, "Score not saved. " + problem)
		return
	var result := {
		"module": module_id, "score": score, "duration_s": duration_s,
		"attempts": _manager.attempts, "device": device_name(),
	}
	if session_id != "":
		result.session_id = session_id
	var reply := {}
	for attempt in max_tries:
		reply = await api.complete_session(result)
		var code: int = reply.get("code", 200)
		# Retry only when the server couldn't be reached or failed; a 4xx won't change.
		if not reply.has("error") or (code != 0 and code < 500):
			break
		if attempt < max_tries - 1 and retry_wait_s > 0:
			await get_tree().create_timer(retry_wait_s * (attempt + 1)).timeout
	if reply.has("error"):
		report_finished.emit(false, "Score not saved. " + reply.error)
	else:
		report_finished.emit(true, "Score saved to %s's progress." % reply.get("learner_id", uid))


## Signs in if needed. Returns "" when signed in, or why not.
func _signed_in() -> String:
	if api.token != "":
		return ""
	return await api.sign_in(uid, password)


func _is_practice() -> bool:
	return _manager == null or bool(_manager.mission.get("practice", false))


static func _setting(env: String, file: ConfigFile, key: String, fallback: String) -> String:
	var value := OS.get_environment(env)
	if value != "":
		return value
	return str(file.get_value("api", key, fallback))
