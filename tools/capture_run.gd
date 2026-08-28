extends "res://tests/test_level.gd"
## Visual validation: play the level with the real controller in a real window and
## save the rendered frames to PNG, so a level change can actually be *looked at*
## end-to-end instead of taken on trust.
##
## The headless suites prove the course is completable, but they render nothing —
## a platform could be mispositioned, mis-sized, or invisible and every assertion
## would still pass. This drives the same autopilot as `tests/test_level.gd`
## (inherited, not copied) while a second coroutine grabs the viewport every few
## frames.
##
## Must run WITHOUT --headless (the headless display server draws nothing):
##   Godot --path <proj> --script res://tools/capture_run.gd
## Frames land in build/shots/ (git-ignored, and .gdignore'd so the engine never
## re-imports them). Exit code 0 = the run reached the goal and frames were saved.

## Where to write frames. Inside build/ on purpose: git-ignored, and the
## build/.gdignore guard keeps the filesystem scanner from importing them.
const SHOT_DIR := "res://build/shots"
## Save one frame in this many. 12 ≈ 5 shots a second at 60 Hz: enough to see
## every jump arc without writing hundreds of files.
const SHOT_INTERVAL := 12
## Give the autopilot room to finish (it needs ~633 frames for the 13-platform route) and then stop.
const FRAME_BUDGET := 700
## Frames to keep capturing after the goal is reached. The completion banner
## fades in over 0.35 s and is the payoff moment of the whole run, so stopping on
## the goal frame photographs it at ~10% opacity and makes a perfectly good
## banner look like a bug. 90 frames ≈ 1.5 s: past the fade-in, inside the hold.
const TAIL_FRAMES := 90

var _goals := [0]
var _finished := false
var _run_frames := 0
var _shots := 0


func _suite_name() -> String:
	return "capture_run"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_check("running with a real display server (drop --headless)", false)
		return
	if not _prepare_dir():
		_check("shot directory is writable (%s)" % SHOT_DIR, false)
		return

	var body: RectangleShape2D = _player.get_node("CollisionShape2D").shape
	_body = body.size
	_main.level_completed.connect(func() -> void: _goals[0] += 1)

	# Start the inherited autopilot *without* awaiting it: it suspends on its own
	# physics_frame awaits, so this coroutine keeps running alongside it and can
	# capture the frames it produces. Awaiting it instead would block until the
	# run was over, with nothing left to photograph.
	_play()

	var frame := 0
	while not _finished and frame < FRAME_BUDGET:
		await RenderingServer.frame_post_draw
		frame += 1
		if frame % SHOT_INTERVAL == 0:
			_save(frame)
	# One last frame on the goal itself, which the interval will usually miss.
	await RenderingServer.frame_post_draw
	_save(frame + 1)
	# Then keep rolling through the completion banner's fade-in and hold.
	for _i in TAIL_FRAMES:
		await RenderingServer.frame_post_draw
		frame += 1
		if frame % SHOT_INTERVAL == 0:
			_save(frame)

	_check("autopilot reached the goal (%s)" % (
		"%d frames" % _run_frames if _run_frames > 0 else "NEVER FINISHED"), _run_frames > 0)
	_check("frames captured (%d in %s)" % [_shots, SHOT_DIR], _shots > 0)


## Wrapper so the capture loop can tell when the inherited autopilot is done.
func _play() -> void:
	_run_frames = await _autopilot(-200.0, _goals)
	_finished = true


## Fresh directory each run, so leftover frames from an older level can't be
## mistaken for this one's.
func _prepare_dir() -> bool:
	var abs_dir := ProjectSettings.globalize_path(SHOT_DIR)
	if DirAccess.make_dir_recursive_absolute(abs_dir) != OK:
		return false
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return false
	for f in dir.get_files():
		if f.ends_with(".png"):
			dir.remove(f)
	return true


func _save(frame: int) -> void:
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		return
	var path := "%s/f%04d.png" % [SHOT_DIR, frame]
	if img.save_png(path) == OK:
		_shots += 1
		print("[shot] %s  player=(%.0f, %.0f)" % [
			path, _player.global_position.x, _player.global_position.y])
