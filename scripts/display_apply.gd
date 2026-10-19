class_name DisplayApply
extends RefCounted
## Window mode, window size, vsync and frame cap. Only what the platform allows is ever applied:
## a browser tab has no window size, vsync or frame cap of its own, only a fullscreen toggle.
## `plan()` is pure (so tests can check every case); `apply()` carries it out on a real window.

const MODE_NAMES: Array[String] = ["WINDOWED", "BORDERLESS", "FULLSCREEN"]
const SIZE_NAMES: Array[String] = ["REMEMBER", "1280 X 720", "1600 X 900", "1920 X 1080", "2560 X 1440"]
const SIZES: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const FPS_NAMES: Array[String] = ["UNLIMITED", "60", "90", "120", "144"]
const FPS_CAPS: Array[int] = [0, 60, 90, 120, 144]


## What to do, as a dictionary: mode ("windowed" / "borderless" / "fullscreen"), size (Vector2i,
## ZERO = leave alone), vsync (bool or null = leave alone), max_fps (int, -1 = leave alone).
static func plan(values: Dictionary, web: bool) -> Dictionary:
	var out := {"mode": "", "size": Vector2i.ZERO, "vsync": null, "max_fps": -1}
	if web:
		# The browser owns the canvas: only fullscreen can be asked for.
		out["mode"] = "fullscreen" if bool(values.get("disp_fullscreen", false)) else "windowed"
		return out
	var mode_idx := clampi(int(values.get("disp_window_mode", 0)), 0, MODE_NAMES.size() - 1)
	out["mode"] = ["windowed", "borderless", "fullscreen"][mode_idx]
	if mode_idx == 0:
		out["size"] = SIZES[clampi(int(values.get("disp_window_size", 0)), 0, SIZES.size() - 1)]
	out["vsync"] = bool(values.get("disp_vsync", true))
	out["max_fps"] = FPS_CAPS[clampi(int(values.get("disp_fps_cap", 0)), 0, FPS_CAPS.size() - 1)]
	return out


static func values_from(gs: Node) -> Dictionary:
	var v := {}
	for k in ["disp_window_mode", "disp_window_size", "disp_vsync", "disp_fps_cap", "disp_fullscreen"]:
		v[k] = gs.get_reg(k)
	return v


static func apply(gs: Node) -> void:
	if gs == null or DisplayServer.get_name() == "headless":
		return
	var p := plan(values_from(gs), Platform.is_web())
	match String(p["mode"]):
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if Platform.is_web() \
				else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"windowed":
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size: Vector2i = p["size"]
			if size != Vector2i.ZERO:
				DisplayServer.window_set_size(size)
				var screen := DisplayServer.screen_get_usable_rect()
				DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
	if p["vsync"] != null:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(p["vsync"]) else DisplayServer.VSYNC_DISABLED)
	if int(p["max_fps"]) >= 0:
		Engine.max_fps = int(p["max_fps"])
