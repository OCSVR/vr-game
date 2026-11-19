extends SceneTree
## One real round trip to a running Flask backend (OCSVR/ocs_backend with the
## training API). Plays the "Identify components" result through the real
## TrainingManager and ScoreReporter, then reads it back from the progress API.
##
##   OCSVR_API_URL=http://localhost:8587 OCSVR_UID=hop OCSVR_PASSWORD=... \
##     godot --headless --script res://tests/run_live_api_test.gd
##
## Use an activated test account. Without the variables it prints SKIPPED.
## It creates real sessions for that account.

const MISSION := "build_computer.identify_components"

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = "") -> void:
	var why := str(detail)
	print(("PASS  " if ok else "FAIL  ") + label + ("" if ok or why == "" else "   [%s]" % why))
	if not ok:
		_failures.append(label)


func _run() -> void:
	var manager := root.get_node("TrainingManager")
	var reporter := root.get_node("ScoreReporter")
	reporter.load_settings()
	if not reporter.is_configured():
		print("SKIPPED: set OCSVR_API_URL, OCSVR_UID and OCSVR_PASSWORD to run against a backend")
		quit(0)
		return
	var reports := []
	reporter.report_finished.connect(func(ok, message): reports.append([ok, message]))

	var before: Dictionary = await _progress(reporter)
	var completed_before: int = before.get("summary", {}).get("sessions_completed", 0)

	manager.now_ms = func() -> int: return 0
	manager.begin(MISSION)
	await _wait(func() -> bool: return reporter.session_id != "" or not reporter._starting, 10.0)
	check("starting the mission starts a session on the server", reporter.session_id.length() == 36, reporter.session_id)
	manager.note_grab()
	manager.note_mistake()
	manager.now_ms = func() -> int: return 123000
	manager.complete()
	await _wait(func() -> bool: return not reports.is_empty(), 15.0)
	check("completing it saves the score", reports.size() == 1 and reports[0][0], reports)

	var after: Dictionary = await _progress(reporter)
	var latest: Dictionary = after.get("recent_sessions", [{}])[0]
	check("the progress API shows one more completed session",
		after.get("summary", {}).get("sessions_completed", -1) == completed_before + 1, after.get("summary"))
	check("and it's this run: same session, score 90, 123 s, 2 attempts, desktop",
		latest.get("session_id") == reporter.session_id and int(latest.get("score", -1)) == 90
			and int(latest.get("duration_s", -1)) == 123 and int(latest.get("attempts", -1)) == 2
			and latest.get("device") == "desktop" and latest.get("status") == "completed", latest)

	print("\n%s" % ("ALL PASSED" if _failures.is_empty() else "%d FAILED" % _failures.size()))
	quit(0 if _failures.is_empty() else 1)


func _progress(reporter: Node) -> Dictionary:
	if await reporter._signed_in() != "":
		return {}
	return await reporter.api.get_progress(reporter.uid)


func _wait(done: Callable, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while not done.call() and Time.get_ticks_msec() < until:
		await process_frame
