extends SceneTree
## Settings v2: search, live theme/font rebuild, character gear, audio FX buses,
## reduce-motion, two-step reset, and persistence of every new field (with
## hostile saved values clamped).

var _failures: int = 0
var _gs: Node


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_gs = root.get_node("GameSettings")
	_gs.reset_settings()
	await _search_and_rebuild()
	await _character()
	_audio_fx()
	await _access()
	await _texture()
	_persistence()
	_gs.reset_settings()
	print("[test_settings_v2] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _visible_rows(page: SettingsPage) -> int:
	var n := 0
	for p in page._pages:
		for c in p.get_children():
			if c.visible and p.visible:
				n += 1
	return n


func _search_and_rebuild() -> void:
	var page := SettingsPage.new()
	root.add_child(page)
	await _step(3)
	page._on_search("shake")
	var shown := 0
	var all_match := true
	for p in page._pages:
		for c in p.get_children():
			if c.visible:
				shown += 1
				var found := false
				for e in page._searchable:
					if e["ctl"] == c and String(e["text"]).contains("shake"):
						found = true
				all_match = all_match and found
	_check("search shows rows across tabs (%d)" % shown, shown >= 2)
	_check("every shown row matches the query", all_match)
	page._on_search("zzzz-nothing")
	_check("a query with no match shows no rows", _visible_rows(page) == 0)
	page._on_search("")
	_check("clearing the search restores the tab view",
		page._pages[page._tab].visible and not page._pages[(page._tab + 1) % 6].visible)

	# Theme applies at once: the page rebuilds with the new accent.
	var before: Color = UITheme.accent
	_gs.apply_theme(1)   # Ember: orange accent
	page._rebuild_deferred()
	await _step(4)
	_check("theme change recolours the open page", UITheme.accent != before)
	# Font choice rebuilds with the new font.
	_gs.font_choice = 1
	page._rebuild_deferred()
	await _step(4)
	_check("font choice is picked up", UITheme.font_index == 1)
	_check("CLEAN font is the engine built-in face", UITheme.make_font(4) == ThemeDB.fallback_font)
	_check("every font choice yields a font", UITheme.FONT_NAMES.size() == 6
		and UITheme.make_font(0) != null and UITheme.make_font(2) != null and UITheme.make_font(3) != null and UITheme.make_font(5) != null)
	_check("the page survives a rebuild and keeps six tabs", page._tab_buttons.size() == 6)
	_gs.font_choice = 0
	_gs.apply_theme(0)
	page.close()
	await _step(3)


func _character() -> void:
	_check("default gear is the backpack, not the scarf",
		_gs.accessory == 0 and _gs.sheet_path().ends_with("player_sheet.png"))
	for i in _gs.ACCESSORIES.size():
		_gs.accessory = i
		_check("gear %s has a sheet that loads" % _gs.ACCESSORIES[i], load(_gs.sheet_path()) is Texture2D)
	_gs.accessory = 2
	_check("scarf is now an opt-in sheet", _gs.sheet_path().ends_with("player_sheet_scarf.png"))
	_gs.accessory = 0

	var preview := CharacterPreview.new()
	root.add_child(preview)
	await _step(3)
	_gs.trim_color = 1
	_gs.visor_color = 2
	preview.refresh()
	var mat: ShaderMaterial = preview._material
	_check("trim colour reaches the sprite",
		(mat.get_shader_parameter("accent") as Color).is_equal_approx(_gs.get_trim_color()))
	_check("visor colour reaches the sprite",
		(mat.get_shader_parameter("visor") as Color).is_equal_approx(_gs.get_visor_color()))
	var first := preview.current_animation()
	preview.advance(CharacterPreview.CYCLE_TIME + 0.1)
	_check("the preview cycles through animations", preview.current_animation() != "" and first != "")
	_gs.accessory = 1
	preview.refresh()
	_check("changing gear swaps the preview's sheet", preview._sheet_path.ends_with("player_sheet_antenna.png"))

	# Live in the real player: change gear and the in-game sprite follows.
	var player: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await _step(6)
	var vis: PlayerVisuals = player.get_node("Visuals")
	_gs.accessory = 3
	_gs.trim_color = 4
	_gs.save_settings()
	await _step(3)
	_check("the in-game sprite swaps gear live", vis._sheet_path.ends_with("player_sheet_none.png"))
	_check("and recolours trim live",
		(vis._material.get_shader_parameter("accent") as Color).is_equal_approx(_gs.get_trim_color()))
	player.queue_free()
	preview.queue_free()
	await _step(2)
	_gs.accessory = 0
	_gs.trim_color = 0
	_gs.visor_color = 0


func _count_effects(bus: int, cls: String) -> int:
	var n := 0
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).get_class() == cls:
			n += 1
	return n


func _effect_on(bus: int, cls: String) -> bool:
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).get_class() == cls:
			return AudioServer.is_bus_effect_enabled(bus, i)
	return false


func _audio_fx() -> void:
	_gs.ui_volume = 0.3
	_gs.audio_room_echo = 0.8
	_gs.audio_night_mode = true
	AudioFx.apply(_gs)
	var ui := AudioServer.get_bus_index(AudioFx.UI_BUS)
	var sfx := AudioServer.get_bus_index("SFX")
	_check("a UI bus exists", ui >= 0)
	_check("UI volume follows the setting",
		is_equal_approx(AudioServer.get_bus_volume_db(ui), linear_to_db(0.3)))
	_check("room echo enables a reverb on SFX", _effect_on(sfx, "AudioEffectReverb"))
	_check("night mode enables a compressor on Master", _effect_on(0, "AudioEffectCompressor"))
	_gs.audio_room_echo = 0.0
	_gs.audio_night_mode = false
	AudioFx.apply(_gs)
	_check("zero echo turns the reverb off again", not _effect_on(sfx, "AudioEffectReverb"))
	_check("night mode off turns the compressor off", not _effect_on(0, "AudioEffectCompressor"))
	AudioFx.apply(_gs)
	AudioFx.apply(_gs)
	_check("applying repeatedly never stacks effects",
		_count_effects(sfx, "AudioEffectReverb") == 1 and _count_effects(0, "AudioEffectCompressor") == 1)
	_check("muffle is off by default", not AudioFx.is_muffled())
	AudioFx.set_muffled(true)
	_check("muffle can be switched on", AudioFx.is_muffled())
	AudioFx.set_muffled(false)
	_gs.ui_volume = 0.6


func _access() -> void:
	var page := SettingsPage.new()
	root.add_child(page)
	await _step(3)
	page._reduce_motion()
	_check("reduce motion zeroes shake", _gs.shake_intensity == 0.0 and not _gs.screen_shake)
	_check("reduce motion turns off flash and background motion",
		not _gs.death_flash and not _gs.bg_motion and not _gs.afterimages)
	await _step(4)
	_gs.accessory = 2
	_gs.font_choice = 3
	var btn := Button.new()
	page._reset_all(btn)
	_check("reset needs a second press", _gs.accessory == 2)
	page._reset_all(btn)
	_check("the second press resets everything",
		_gs.accessory == 0 and _gs.font_choice == 0 and _gs.shake_intensity == 1.0)
	btn.free()
	page.close()
	await _step(3)


func _texture() -> void:
	var filter := PixelFilter.new()
	root.add_child(filter)
	await _step(3)
	var mat: ShaderMaterial = filter._material
	var normal_block: float = mat.get_shader_parameter("block_px")
	_gs.pixel_mode = 0
	_gs.save_settings()
	await _step(2)
	_check("pixel OFF removes the grid snap", is_equal_approx(float(mat.get_shader_parameter("block_px")), 1.0))
	_check("pixel OFF removes dither and banding",
		is_equal_approx(float(mat.get_shader_parameter("dither_strength")), 0.0) and float(mat.get_shader_parameter("levels")) >= 255.0)
	_gs.pixel_mode = 2
	_gs.save_settings()
	await _step(2)
	_check("CHUNKY doubles the pixel size", is_equal_approx(float(mat.get_shader_parameter("block_px")), normal_block * 2.0))
	_gs.pixel_mode = 1
	_gs.pixel_dither = 0.4
	_gs.pixel_levels = 8
	_gs.scanlines = 0.7
	_gs.save_settings()
	await _step(2)
	_check("NORMAL restores the grid", is_equal_approx(float(mat.get_shader_parameter("block_px")), normal_block))
	_check("dither strength follows the slider", is_equal_approx(float(mat.get_shader_parameter("dither_strength")), 0.4))
	_check("colour steps follow the slider", is_equal_approx(float(mat.get_shader_parameter("levels")), 8.0))
	_check("scanlines follow the slider", is_equal_approx(float(mat.get_shader_parameter("scanline_strength")), 0.7))
	filter.queue_free()

	# Platform surface: BRICK uses the stone texture, FLAT drops it, live.
	var plat: GreyboxPlatform = (load("res://scenes/platform.tscn") as PackedScene).instantiate()
	root.add_child(plat)
	await _step(3)
	var poly: Polygon2D = plat.get_node("Polygon2D")
	_check("BRICK platforms are textured", poly.texture != null)
	_gs.tile_style = 1
	_gs.save_settings()
	await _step(2)
	_check("FLAT drops the texture live", poly.texture == null)
	_gs.tile_style = 0
	_gs.save_settings()
	await _step(2)
	_check("and BRICK brings it back", poly.texture != null)
	plat.queue_free()
	await _step(2)
	_gs.pixel_dither = 1.0
	_gs.pixel_levels = 20
	_gs.scanlines = 0.0


func _persistence() -> void:
	_gs.accessory = 3
	_gs.visor_color = 4
	_gs.trim_color = 5
	_gs.font_choice = 2
	_gs.ui_volume = 0.25
	_gs.audio_room_echo = 0.4
	_gs.audio_night_mode = true
	_gs.pause_on_focus_loss = true
	_gs.pixel_mode = 2
	_gs.scanlines = 0.3
	_gs.pixel_levels = 12
	_gs.tile_style = 1
	_gs.save_settings()
	_gs.pixel_mode = 1
	_gs.scanlines = 0.0
	_gs.pixel_levels = 20
	_gs.tile_style = 0
	_gs.accessory = 0
	_gs.visor_color = 0
	_gs.trim_color = 0
	_gs.font_choice = 0
	_gs.ui_volume = 0.6
	_gs.audio_room_echo = 0.0
	_gs.audio_night_mode = false
	_gs.pause_on_focus_loss = false
	_gs.load_settings()
	_check("gear, colours and font persist",
		_gs.accessory == 3 and _gs.visor_color == 4 and _gs.trim_color == 5 and _gs.font_choice == 2)
	_check("audio fx settings persist",
		is_equal_approx(_gs.ui_volume, 0.25) and is_equal_approx(_gs.audio_room_echo, 0.4) and _gs.audio_night_mode)
	_check("focus pause persists", _gs.pause_on_focus_loss)
	_check("texture settings persist", _gs.pixel_mode == 2 and is_equal_approx(_gs.scanlines, 0.3) and _gs.pixel_levels == 12 and _gs.tile_style == 1)
	# Hostile file: out-of-range and wrong-type values must clamp, never crash.
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	f.store_string("{\"accessory\": 99, \"visor_color\": -4, \"trim_color\": \"red\", \"font_choice\": 1e9, \"ui_volume\": 7, \"audio_night_mode\": \"yes\"}")
	f.close()
	_gs.load_settings()
	_check("hostile accessory index clamps", _gs.accessory >= 0 and _gs.accessory < _gs.ACCESSORIES.size())
	_check("hostile visor index clamps", _gs.visor_color >= 0)
	_check("wrong-typed trim stays a valid index", _gs.trim_color >= 0 and _gs.trim_color < _gs.TRIM_COLORS.size())
	_check("hostile font index clamps", _gs.font_choice >= 0 and _gs.font_choice < UITheme.FONT_NAMES.size())
	_check("hostile volume clamps to 0..1", _gs.ui_volume >= 0.0 and _gs.ui_volume <= 1.0)
