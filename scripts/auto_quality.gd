class_name AutoQuality
extends Node
## Watches real frame times. (1) At the first launch it times the title scene and picks a
## graphics preset for the machine. (2) While playing, if the frame rate stays poor window
## after window, it offers to lower the preset (it never changes anything silently).
## Uses medians and a high percentile over whole windows, never a single slow frame, with a
## cooldown, so one hitch (a level load, alt-tab) cannot trigger anything.

signal detected(preset: int)
signal struggling(current: int, suggested: int)

const WARMUP_FRAMES := 45          # shader compiles and the first draws are not representative
const DETECT_FRAMES := 150
const WINDOW_FRAMES := 360         # about 6 s at 60 fps
const STRUGGLE_WINDOWS := 2        # in a row
const COOLDOWN_WINDOWS := 5

var _frames: Array[float] = []
var _warm: int = 0
var _detecting: bool = true
var _bad_windows: int = 0
var _cooldown: int = 0
var _suggested: bool = false
var _gs: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("auto_quality")
	_gs = get_node_or_null("/root/GameSettings")
	# Detection only runs once per install, and only if the player left quality on AUTO.
	_detecting = _gs != null and int(_gs.get_reg("gfx_detected")) < 0 and int(_gs.get_reg("gfx_quality")) == 0
	set_process(DisplayServer.get_name() != "headless")


func _process(delta: float) -> void:
	feed(delta)


## One frame's time in seconds. Public so tests can drive the logic with exact numbers.
func feed(delta: float) -> void:
	if _detecting:
		if _warm < WARMUP_FRAMES:
			_warm += 1
			return
		_frames.append(delta * 1000.0)
		if _frames.size() >= DETECT_FRAMES:
			_finish_detection()
		return
	_frames.append(delta * 1000.0)
	if _frames.size() >= WINDOW_FRAMES:
		_close_window()


func current_preset() -> int:
	var chosen: int = int(_gs.get_reg("gfx_quality")) if _gs != null else 0
	if chosen == GraphicsQuality.Preset.AUTO:
		var d: int = int(_gs.get_reg("gfx_detected")) if _gs != null else -1
		return d if d > 0 else GraphicsQuality.Preset.HIGH
	return chosen


func _finish_detection() -> void:
	var median := GraphicsQuality.percentile(_frames, 0.5)
	var renderer := RenderingServer.get_video_adapter_name()
	var pick := GraphicsQuality.pick_for(median, renderer, Platform.is_web())
	_frames.clear()
	_detecting = false
	if _gs != null:
		_gs.set_reg("gfx_detected", pick, false)
		GraphicsQuality.apply(_gs, pick)
	detected.emit(pick)


func _close_window() -> void:
	var p95 := GraphicsQuality.percentile(_frames, 0.95)
	_frames.clear()
	if _cooldown > 0:
		_cooldown -= 1
		return
	if p95 > GraphicsQuality.STRUGGLE_P95_MS:
		_bad_windows += 1
	else:
		_bad_windows = 0
	var cur := current_preset()
	if _bad_windows >= STRUGGLE_WINDOWS and cur > GraphicsQuality.Preset.LOW and not _suggested:
		_suggested = true
		_bad_windows = 0
		_cooldown = COOLDOWN_WINDOWS
		struggling.emit(cur, GraphicsQuality.lower(cur))
	elif _bad_windows >= STRUGGLE_WINDOWS:
		_bad_windows = 0


## Measure again now (the player picked AUTO in Settings).
func restart_detection() -> void:
	_detecting = true
	_warm = 0
	_frames.clear()
	if _gs != null:
		_gs.set_reg("gfx_detected", -1.0, false)


## The player answered the offer (or changed quality themselves): allow a future offer after
## the cooldown only if they declined.
func reset_offer() -> void:
	_suggested = false
