extends SceneTree
## Two guards over EVERY setting the game stores:
##  (1) NO DEAD SETTINGS: each stored setting is read by something other than the settings page
##      and the file that stores it. (This project has shipped settings that did nothing before;
##      this scan fails the build if a setting exists only in the menu.)
##  (2) ROUND TRIP: every setting survives save -> forget -> load with its changed value.

var _failures: int = 0
var _gs: Node

## Stored values that are state, not options a consumer reads by that name.
const STATE_KEYS := ["reg", "key_bindings"]
## Settings the store itself acts on: key -> the function in game_settings.gd whose body reads it.
## Each of those functions must exist, mention the key, and (for accessors) be called elsewhere.
const CONSUMED_IN_STORE := {
	"audio_pause_muffle": ["_process", ""], "audio_mute_unfocused": ["_notification", ""],
	"pause_on_focus_loss": ["_notification", ""], "stick_deadzone": ["apply_stick_deadzone", ""],
	"accessory": ["sheet_path", "sheet_path"], "visor_color": ["get_visor_color", "get_visor_color"],
	"trim_color": ["get_trim_color", "get_trim_color"], "player_color": ["get_player_color", "get_player_color"],
	"accent_color": ["get_accent_color", "get_accent_color"],
}
## Settings read through a helper that takes the name from a list rather than a literal.
const READ_THROUGH := {
	"disp_window_mode": "display_apply.gd", "disp_window_size": "display_apply.gd",
	"disp_vsync": "display_apply.gd", "disp_fps_cap": "display_apply.gd", "disp_fullscreen": "display_apply.gd",
}


func _initialize() -> void:
	_boot()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _boot() -> void:
	await physics_frame
	_gs = root.get_node("GameSettings")
	_gs.reset_settings()
	_no_dead_settings()
	_round_trip()
	print("[test_settings_integrity] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


# ── helpers ─────────────────────────────────────────────────────────

func _script_texts() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("res://scripts")
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			var fa := FileAccess.open("res://scripts/" + f, FileAccess.READ)
			if fa != null:
				out[f] = fa.get_as_text()
	return out


## True when `needle` appears in a script other than the excluded ones.
func _used_elsewhere(texts: Dictionary, needle: String, excluded: Array) -> bool:
	for f in texts:
		if f in excluded:
			continue
		if String(texts[f]).contains(needle):
			return true
	return false


## The text of one function (from its `func` line to the next top-level `func`).
func _func_body(text: String, fname: String) -> String:
	var start := text.find("func %s(" % fname)
	if start < 0:
		return ""
	var end := text.find("
func ", start + 5)
	return text.substr(start, (end if end > 0 else text.length()) - start)


# ── (1) dead settings ───────────────────────────────────────────────

func _no_dead_settings() -> void:
	var texts := _script_texts()
	_check("the scan can read the scripts (%d files)" % texts.size(), texts.size() > 80)
	var dead: Array = []
	# Registered settings: someone must call get_reg("key") (or a listed helper reads it).
	for d in SettingsRegistry.all():
		var key := String(d["key"])
		if bool(d.get("hidden", false)):
			continue
		var excluded := ["settings_registry.gd", "settings_page.gd"]
		var needle := "\"%s\"" % key
		var used := _used_elsewhere(texts, needle, excluded)
		if not used and READ_THROUGH.has(key):
			used = String(texts.get(READ_THROUGH[key], "")).contains(needle)
		if not used:
			dead.append(key)
	_check("every registered setting is read by real code %s" % str(dead), dead.is_empty())
	# Legacy fields: each stored name is used outside the page and the store.
	var dead_fields: Array = []
	var dict: Dictionary = _gs.settings_dict()
	for key in dict:
		if key in STATE_KEYS:
			continue
		var key_s := String(key)
		var excluded2 := ["settings_page.gd", "game_settings.gd", "pause_menu.gd"]
		# A setting is "used" when another script names it as a property (.key) or a string.
		var used2 := _used_elsewhere(texts, "." + key_s, excluded2) or _used_elsewhere(texts, "\"%s\"" % key_s, excluded2)
		# The pause menu has its own copies of a few quick toggles; count a read there too.
		if not used2:
			used2 = String(texts.get("pause_menu.gd", "")).contains("." + key_s)
		if not used2 and CONSUMED_IN_STORE.has(key_s):
			var spec: Array = CONSUMED_IN_STORE[key_s]
			var body := _func_body(String(texts.get("game_settings.gd", "")), String(spec[0]))
			used2 = body.contains(key_s)
			if used2 and String(spec[1]) != "":
				used2 = _used_elsewhere(texts, String(spec[1]) + "(", ["game_settings.gd", "settings_page.gd"])
		if not used2:
			dead_fields.append(key_s)
	_check("every stored setting is read by something besides its own menu %s" % str(dead_fields), dead_fields.is_empty())
	# Negative control: the scan really does flag a name nobody reads.
	var control := _used_elsewhere(texts, "\"definitely_not_a_setting_zzz\"", ["settings_registry.gd"])
	_check("negative control: an invented setting is reported as unused", not control)


# ── (2) round trip ──────────────────────────────────────────────────

func _round_trip() -> void:
	_gs.reset_settings()
	# Change every plain field to a legal non-default value.
	var changed := {}
	var dict: Dictionary = _gs.settings_dict()
	for key in dict:
		if key in STATE_KEYS or key == "reg":
			continue
		var cur = dict[key]
		var next = cur
		if cur is bool:
			next = not cur
		elif cur is int:
			next = _next_index(String(key), int(cur))
		elif cur is float:
			next = 0.37 if not is_equal_approx(float(cur), 0.37) else 0.62
		changed[key] = next
		_gs.set(key, next)
	# And every registered setting.
	var reg_changed := {}
	for d in SettingsRegistry.all():
		var key := String(d["key"])
		var v = SettingsRegistry.default_of(key)
		match String(d["kind"]):
			"toggle":
				v = not bool(v)
			"slider":
				v = clampf((float(d["lo"]) + float(d["hi"])) * 0.5, float(d["lo"]), float(d["hi"]))
				if is_equal_approx(float(v), float(SettingsRegistry.default_of(key))):
					v = float(d["hi"])
			"choice":
				v = ((int(v) + 1) % (d["names"] as Array).size())
		reg_changed[key] = SettingsRegistry.sanitize(key, v)
		_gs.set_reg(key, v, false)
	_gs.save_settings()
	# Forget in memory, then reload from the file.
	for key in changed:
		_gs.set(key, dict[key])
	_gs.reg = {}
	_gs.load_settings()
	var bad: Array = []
	for key in changed:
		var got = _gs.get(key)
		var want = changed[key]
		var same: bool = got == want
		if got is float or want is float:
			same = is_equal_approx(float(got), float(want))
		if not same:
			bad.append("%s %s!=%s" % [key, str(got), str(want)])
	_check("every stored field survives a save and reload (%d fields) %s" % [changed.size(), str(bad.slice(0, 4))], bad.is_empty() and changed.size() > 30)
	var bad_reg: Array = []
	for key in reg_changed:
		var got = _gs.get_reg(key)
		var want = reg_changed[key]
		var same2: bool = got == want
		if got is float or want is float:
			same2 = is_equal_approx(float(got), float(want))
		if not same2:
			bad_reg.append("%s %s!=%s" % [key, str(got), str(want)])
	_check("every registered setting survives a save and reload (%d) %s" % [reg_changed.size(), str(bad_reg.slice(0, 4))], bad_reg.is_empty())
	# A reset really restores them all.
	_gs.reset_settings()
	var after: Dictionary = _gs.settings_dict()
	var fresh: Array = []
	for key in changed:
		if key in ["intro_seen", "tutorial_done"]:
			continue
		var a = after[key]
		var d0 = changed[key]
		if a == d0 or (a is float and is_equal_approx(float(a), float(d0))):
			fresh.append(key)
	_check("reset moves every changed field off its changed value %s" % str(fresh.slice(0, 4)), fresh.is_empty())
	_check("reset clears every registered setting", _gs.reg.is_empty())


func _next_index(key: String, cur: int) -> int:
	match key:
		"pixel_mode": return (cur + 1) % GameSettings.PIXEL_MODE_NAMES.size()
		"tile_style": return (cur + 1) % GameSettings.TILE_STYLE_NAMES.size()
		"pixel_levels": return GameSettings.PIXEL_LEVELS_MIN + 4 if cur != GameSettings.PIXEL_LEVELS_MIN + 4 else GameSettings.PIXEL_LEVELS_MIN + 6
		"font_choice": return (cur + 1) % UITheme.FONT_NAMES.size()
		"accessory": return (cur + 1) % GameSettings.ACCESSORIES.size()
		"visor_color": return (cur + 1) % GameSettings.VISOR_COLORS.size()
		"trim_color": return (cur + 1) % GameSettings.TRIM_COLORS.size()
		"player_color": return (cur + 1) % GameSettings.PLAYER_COLORS.size()
		"accent_color": return (cur + 1) % GameSettings.ACCENT_COLORS.size()
		"theme": return (cur + 1) % GameSettings.THEMES.size()
		"feel_preset": return (cur + 1) % Feel.VALUES.size()
	return cur + 1 if cur < 3 else cur - 1
