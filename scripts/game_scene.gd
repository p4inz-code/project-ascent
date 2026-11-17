# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
extends Node2D
## Main game scene that manages level loading, transitions, pause overlay,
## and the overall game flow.
##
## This replaces main_scene.tscn as the entry point. It loads the current
## level as a child and overlays the pause menu.

## Time the completion banner is visible before the fade-out begins (s).
@export var completion_banner_time: float = 2.6      # long enough to read the results card; a press skips
## Time to fade to black before the next level loads (s).
@export var fade_out_time: float = 0.5
## Time the level-name card is visible before fading in (s).
@export var level_card_hold: float = 1.1
## Time to fade from black back to gameplay (s).
@export var fade_in_time: float = 0.5

var _current_level_scene: Node2D = null
var _pause_menu: CanvasLayer = null
var _level_container: Node2D
var _transition_overlay: ColorRect
var _transition_label: Label
var _transitioning: bool = false
var _home_button: Button = null
var _completion_pending: bool = false
## Per-act cover drawn over the fade (see TransitionFx).
var _fx: TransitionFx = null
## True from the moment a level is completed (or a level change starts) until the next
## level's fade-in has finished: the player cannot move, and the run clock cannot start.
var _hold_player: bool = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var lv := 0
		if _current_level_scene != null and is_instance_valid(_current_level_scene):
			lv = int(_current_level_scene.get("level_number"))
		Telemetry.record("quit", {"level": lv})
		Telemetry.save()


## A plain notice, once, when this release folder was changed after it was signed (malware repacks).
func _show_integrity_notice() -> void:
	var text := Integrity.notice_text(Integrity.check(Integrity.release_dir()))
	if text == "":
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	label.position = Vector2(24, 20)
	layer.add_child(label)
	add_child(layer)
	var tw := create_tween()
	tw.tween_interval(12.0)
	tw.tween_callback(layer.queue_free)


func _ready() -> void:
	_show_integrity_notice()
	# Engine.time_scale is a global singleton the dev console's slow-motion
	# tool (Pause key) changes, and nothing else in the game ever touches it.
	# Without this, a tester who slows down to inspect one jump and forgets to
	# cycle back would have EVERY subsequent level run in slow motion with no
	# visible cause once the dev overlay is hidden - exactly the kind of thing
	# that produces a false "the game feels broken" report the night before a
	# release. Reset on every level transition, since that is a natural,
	# frequent point to guarantee a clean state.
	Engine.time_scale = 1.0
	# In the real game every level load places its gates and pipes in a fresh valid set of gaps.
	LevelData.random_placement = true

	# Live-apply FX settings while the level is running. Without this the
	# parallax and glow dials only took effect on the NEXT level load, so
	# dragging a slider in the pause menu appeared to do nothing at all —
	# which is exactly how they were reported as broken.
	var gs_live := get_node_or_null("/root/GameSettings")
	if gs_live != null and gs_live.has_signal("settings_changed"):
		if not gs_live.settings_changed.is_connected(_on_fx_settings_changed):
			gs_live.settings_changed.connect(_on_fx_settings_changed)

	# Title screen. An overlay on the running game rather than a scene in front
	# of it, so the pause menu and every autoload are already alive underneath
	# and SETTINGS can open the real panel instead of a second copy.
	# --skip-menu is passed by the launcher: someone who already clicked Play
	# there should not have to click it again.
	if _should_show_start_menu():
		call_deferred("_show_start_menu")

	_level_container = Node2D.new()
	_level_container.name = "LevelContainer"
	add_child(_level_container)

	# Transition overlay
	var canvas := CanvasLayer.new()
	canvas.layer = 150
	canvas.name = "TransitionLayer"
	add_child(canvas)
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color(0, 0, 0, 0)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_transition_overlay)
	_fx = TransitionFx.new()
	_fx.name = "TransitionFx"
	canvas.add_child(_fx)
	# The level card: a plate (see _style_card) that sizes itself to the text and sits in the middle of the cover.
	var card_centre := CenterContainer.new()
	card_centre.name = "CardCentre"
	card_centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(card_centre)
	_card_plate = PanelContainer.new()
	_card_plate.name = "CardPlate"
	_card_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_centre.add_child(_card_plate)
	var card_pad := MarginContainer.new()
	for side in ["left", "right"]:
		card_pad.add_theme_constant_override("margin_" + side, 72)
	for side in ["top", "bottom"]:
		card_pad.add_theme_constant_override("margin_" + side, 44)
	_card_plate.add_child(card_pad)
	_transition_label = Label.new()
	_transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# the game's own pixel face, whatever interface font the player picked: the card is part of the world
	var card_font: Font = UITheme.make_font(0)
	if card_font != null:
		_transition_label.add_theme_font_override("font", card_font)
	_transition_label.add_theme_font_size_override("font_size", UITheme.sz(40))
	_transition_label.add_theme_constant_override("shadow_offset_x", 3)
	_transition_label.add_theme_constant_override("shadow_offset_y", 3)
	_transition_label.add_theme_constant_override("line_spacing", 2)
	card_pad.add_child(_transition_label)
	_transition_label.visible = false
	_card_plate.visible = false
	_style_card(1)

	# Load pause menu
	var pause_scene := load("res://scenes/pause_menu.tscn") as PackedScene
	if pause_scene != null:
		_pause_menu = pause_scene.instantiate()
		add_child(_pause_menu)

	# The home icon: always in the corner, takes you back to the title screen.
	var home_layer := CanvasLayer.new()
	home_layer.layer = 110
	home_layer.name = "HomeLayer"
	add_child(home_layer)
	var home := HomeButton.new()
	home.name = "HomeButton"
	home.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	home.offset_left = -78.0
	home.offset_top = -78.0
	home.offset_right = -24.0
	home.offset_bottom = -24.0
	home.pressed.connect(go_home)
	home_layer.add_child(home)
	_home_button = home

	# Frame-time watcher: picks a graphics preset on first launch and offers to lower it if
	# the frame rate stays poor.
	var aq := AutoQuality.new()
	aq.name = "AutoQuality"
	add_child(aq)
	aq.struggling.connect(_on_quality_struggling)

	# Connect to GameManager
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.pause_menu = _pause_menu
		gm.level_changed.connect(_on_level_changed)
		gm.game_over.connect(_on_game_over)

	# Start the game
	_load_current_level()


func _load_current_level() -> void:
	# _completion_pending guards against a signal double-fire on the level
	# currently loaded. It must be cleared here — not only in
	# _on_level_changed(), which normal level-to-level progression never
	# calls — otherwise it stays true forever after the very first
	# completion and silently swallows every completion after that: no
	# banner, no sound, no advance. This was a real, confirmed bug (the
	# game was stuck after level 2 in any continuous session).
	_completion_pending = false
	# Safety nets: a load never inherits a death freeze, and only the LAST load of overlapping requests
	# builds a level (two loads in flight each instantiated a level: two players, one of them frozen).
	HitStop.clear(get_tree())
	_load_token += 1
	var my_token := _load_token

	# Stop any existing audio before clearing the level
	var old_audio = _find_audio()
	if old_audio != null:
		if old_audio.has_method("stop_wall_slide"):
			old_audio.stop_wall_slide()

	# Clear existing level
	for child in _level_container.get_children():
		child.queue_free()
	await get_tree().process_frame  # Let queue_free complete
	if my_token != _load_token:
		return      # a newer load started meanwhile; it builds the level
	for child in _level_container.get_children():
		_level_container.remove_child(child)
		child.queue_free()

	var gm = get_node_or_null("/root/GameManager")
	var level_num: int = 1
	if gm != null:
		level_num = gm.current_level

	# Load main_scene as the level (it handles all 5 levels via LevelData)
	var scene = load("res://scenes/main_scene.tscn") as PackedScene
	if scene == null:
		push_error("GameScene: cannot load main_scene.tscn")
		return
	_current_level_scene = scene.instantiate()
	_current_level_scene.set("level_number", level_num)
	_level_container.add_child(_current_level_scene)
	# A level that loads behind a transition does not start until the screen is clear.
	_set_player_locked(_hold_player)

	# Hud's own _ready() connects its own completion-banner handler to the
	# level's level_completed signal — that path is correct for the old
	# single-level standalone mode, but here it races with this script's own
	# handler on the SAME banner nodes. Its auto-hide timer doesn't know a
	# multi-level run is in progress (or that the campaign just ended), so it
	# was silently hiding the banner this script had just set to "ALL LEVELS
	# COMPLETE" a couple seconds later. This script owns the banner for the
	# whole multi-level run, so disconnect Hud's independent handler.
	var level_hud = _current_level_scene.get_node_or_null("Hud")
	if level_hud != null and _current_level_scene.level_completed.is_connected(level_hud._on_level_completed):
		_current_level_scene.level_completed.disconnect(level_hud._on_level_completed)

	# Apply per-level visual theming to the backdrop
	var backdrop = _current_level_scene.get_node_or_null("Backdrop")
	if backdrop != null:
		_backdrop_level = level_num
		_apply_level_colors(backdrop, LevelData.visual_level(level_num))

	# Connect level completion
	if _current_level_scene.has_signal("level_completed"):
		_current_level_scene.level_completed.connect(_on_level_completed)
	if _current_level_scene.has_signal("respawned"):
		_current_level_scene.respawned.connect(_on_level_respawned)


func _find_audio():
	if _current_level_scene != null and is_instance_valid(_current_level_scene):
		return _current_level_scene.get_node_or_null("Audio")
	return null


## F10 opens Settings from anywhere in the game (not on the title screen, which
## has its own SETTINGS button): it pauses, and closing the page returns to play.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if (event as InputEventKey).keycode != KEY_F10:
		return
	if get_node_or_null("StartMenu") != null:
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or gm.pause_menu == null or not gm.pause_menu.has_method("show_settings"):
		return
	get_viewport().set_input_as_handled()
	if not gm.is_paused:
		gm.pause_game()
	gm.pause_menu.show_settings()


## Tutorial complete: a short "well done", then on to level 1 (first launch) or back to the
## title (replayed from the menu).
func _finish_tutorial() -> void:
	var gs := get_node_or_null("/root/GameSettings")
	if gs != null:
		gs.tutorial_done = true
		gs.save_settings()
	if _current_level_scene != null:
		var p = _current_level_scene.get_node_or_null("Player")
		if p != null and p.has_method("lock_input"):
			p.lock_input()
	_transition_label.text = "TUTORIAL COMPLETE

YOU ARE READY."
	_transition_label.visible = true
	_transition_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 0.85, 0.5)
	tween.tween_interval(1.8)
	tween.tween_callback(func() -> void:
		_transition_label.visible = false
		_transition_overlay.color.a = 0.0
		_leave_tutorial())


## Leave the tutorial (finished or skipped): straight on to level 1 if it was offered on a
## first launch, otherwise back to the title.
func _leave_tutorial() -> void:
	# After the tutorial (or skipping it) comes PIP's briefing, once.
	var gs0 := get_node_or_null("/root/GameSettings")
	if gs0 != null and not bool(gs0.get_reg("gp_briefed")) and get_node_or_null("Briefing") == null 			and DisplayServer.get_name() != "headless":
		var br := BriefingScreen.new()
		br.name = "Briefing"
		add_child(br)
		get_tree().paused = true
		br.closed.connect(func() -> void:
			get_tree().paused = false
			_leave_tutorial())
		return
	var gm = get_node_or_null("/root/GameManager")
	var chained: bool = gm != null and gm.tutorial_chained
	if gm != null:
		gm.end_tutorial()
		gm.level_changed.emit(gm.current_level)
	if not chained:
		go_home()


## Skip the tutorial from the pause menu. Counts as seen, so it is never offered again.
func skip_tutorial() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null or not gm.tutorial_active:
		return
	var gs := get_node_or_null("/root/GameSettings")
	if gs != null:
		gs.tutorial_done = true
		gs.save_settings()
	gm.resume_game()
	_completion_pending = true
	_leave_tutorial()


var _card_text: String = ""


func _on_level_changed(level_number: int, card_only: bool = false) -> void:
	# Clear any pending completion state
	if not card_only:
		_completion_pending = false

	# If restarting the same level, skip the full transition animation
	if not card_only and _current_level_scene != null and _current_level_scene.get("level_number") == level_number:
		_load_current_level()
		return

	# Show level card (name + number) during fade-in
	if not card_only:
		_transitioning = true
	var level_def = LevelData.get_level(level_number)
	var subtitle := ""
	match level_number:
		1: subtitle = "Learn the basics"
		2: subtitle = "Wider gaps, bigger jumps"
		3: subtitle = "Master the movement"
		4: subtitle = "Precision under pressure"
		5: subtitle = "Survive the chase"
		6: subtitle = "Push through endurance"
		7: subtitle = "Every platform matters"
		8: subtitle = "Chain your moves"
		9: subtitle = "The pressure builds"
		10: subtitle = "Can you escape again?"
		11: subtitle = "Into the unknown"
		12: subtitle = "Climb beyond limits"
		13: subtitle = "Deep and dangerous"
		14: subtitle = "No mercy left"
		15: subtitle = "Escape the shadows"
		16: subtitle = "The storm arrives"
		17: subtitle = "One step from ruin"
		18: subtitle = "Chaos in motion"
		19: subtitle = "The edge awaits"
		20: subtitle = "Eye of the storm"
		21: subtitle = "The final ascent"
		22: subtitle = "Peak precision"
		23: subtitle = "Endure and overcome"
		24: subtitle = "Almost there"
		25: subtitle = "Dawn breaks free"
		26: subtitle = "Below the Spire"
		27: subtitle = "Steam on every wall"
		28: subtitle = "Nothing here is quiet"
		29: subtitle = "Slide or be crushed"
		30: subtitle = "The hive hums"
		31: subtitle = "The sky has a crack"
		32: subtitle = "Shards in the wind"
		33: subtitle = "The ground drifts"
		34: subtitle = "Do not look into it"
		35: subtitle = "The warden of the rift"
		36: subtitle = "The heart of the Spire"
		37: subtitle = "Too hot to think"
		38: subtitle = "Almost nothing left"
		39: subtitle = "One stair, one fall"
		40: subtitle = "Everything you learned"
	var act := ""
	if level_number <= 5: act = "ACT I — LEARN"
	elif level_number <= 10: act = "ACT II — MASTER"
	elif level_number <= 15: act = "ACT III — SURVIVE"
	elif level_number <= 20: act = "ACT IV — ENDURE"
	elif level_number <= 25: act = "ACT V — ASCEND"
	elif level_number <= 30: act = "ACT VI — UNDERWORKS"
	elif level_number <= 35: act = "ACT VII — RIFT"
	else: act = "ACT VIII — CORE"
	var boss_tag := "\n\nB O S S" if level_number % 5 == 0 else ""
	_card_text = ("%s\n\nLEVEL %d — %s\n\n%s" % [act, level_number, level_def.name, subtitle]) + boss_tag
	# ENDLESS never names a campaign level: the card says which stage this is and which biomes it mixes.
	var gm_card := get_node_or_null("/root/GameManager")
	if gm_card != null and gm_card.endless_active:
		var names: Array = []
		for b in gm_card.endless_mix:
			names.append(String(b).to_upper())
		_card_text = "ENDLESS\n\nSTAGE %d\n\n%s" % [int(gm_card.endless_streak) + 1, "  >  ".join(names)]
	_style_card(level_number)
	if card_only:
		return
	_transition_label.text = _card_text
	_transition_label.visible = true
	_transition_label.modulate.a = 0.0

	# Close the act's cover, swap the level behind it, show the card, open again.
	_hold_player = true
	_set_player_locked(true)
	_fx.style = TransitionFx.style_for_level(level_number)
	# One transition at a time: a running one (or a respawn shutter) is cancelled, never left fighting over the
	# cover. Two tweens driving the same cover left it stuck part-way with the screen dimmed.
	_kill_transition_tweens()
	var tween := create_tween()
	_level_tween = tween
	tween.tween_property(_transition_overlay, "color:a", 1.0, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_fx, "cover", 1.0, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_transition_label, "modulate:a", 1.0, 0.2)
	tween.tween_callback(_do_level_swap)
	tween.tween_interval(level_card_hold)
	tween.tween_property(_transition_label, "modulate:a", 0.0, 0.2)
	tween.tween_property(_transition_overlay, "color:a", 0.0, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_fx, "cover", 0.0, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_transition_label.visible = false
		_transitioning = false
		_hold_player = false
		_set_player_locked(false)
	)


## Card colours per act: [text, plate border]. The card takes the colour of the biome it announces.
const CARD_COLOURS := [
	[Color(0.55, 0.82, 1.0), Color(0.46, 0.62, 0.80)],      # I    learn (steel blue)
	[Color(1.0, 0.72, 0.36), Color(0.80, 0.50, 0.24)],      # II   scrapyard (rust amber)
	[Color(0.74, 0.92, 1.0), Color(0.45, 0.72, 0.92)],      # III  freezer (ice)
	[Color(0.66, 0.80, 1.0), Color(0.42, 0.52, 0.80)],      # IV   storm (slate blue)
	[Color(1.0, 0.82, 0.45), Color(0.95, 0.60, 0.22)],      # V    forge (gold)
	[Color(0.55, 0.92, 0.90), Color(0.30, 0.62, 0.64)],     # VI   underworks (teal)
	[Color(0.84, 0.70, 1.0), Color(0.60, 0.42, 0.92)],      # VII  rift (violet)
	[Color(1.0, 0.56, 0.44), Color(0.90, 0.34, 0.26)],      # VIII core (red)
]


## The level card sits on its own dark plate with a pixel border in the act's colour. Without the plate the text
## was drawn straight onto the cover, where the airlock's centre seam and warning blocks ran through the words.
func _style_card(level_number: int) -> void:
	var act: int = clampi((level_number - 1) / 5, 0, CARD_COLOURS.size() - 1)
	var cols: Array = CARD_COLOURS[act]
	_transition_label.add_theme_color_override("font_color", cols[0])
	_transition_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	if _card_plate == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.07, 0.96)
	sb.border_color = cols[1]
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(12, 12)
	_card_plate.add_theme_stylebox_override("panel", sb)


## A quick shutter on every death and restart: the act's cover is already shut on the frame the player is put
## back, then opens over a quarter of a second. The player is frozen for that long (the run clock cannot start),
## so nothing happens behind a closed cover.
func _on_level_respawned(completed: bool) -> void:
	if completed or _transitioning or _hold_player or _fx == null:
		return
	if DisplayServer.get_name() == "headless":
		return
	if _respawn_tween != null and _respawn_tween.is_valid():
		_respawn_tween.kill()
	var lv := int(_current_level_scene.get("level_number")) if _current_level_scene != null else 1
	_fx.style = TransitionFx.style_for_level(lv)
	_fx.cover = 1.0
	_set_player_locked(true)
	_respawn_tween = create_tween()
	_respawn_tween.tween_interval(0.07)
	_respawn_tween.tween_property(_fx, "cover", 0.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_respawn_tween.tween_callback(func() -> void:
		if not _hold_player:
			_set_player_locked(false))


var _respawn_tween: Tween = null
var _level_tween: Tween = null
var _load_token: int = 0


func _kill_transition_tweens() -> void:
	for t in [_respawn_tween, _level_tween]:
		if t != null and (t as Tween).is_valid():
			(t as Tween).kill()
	_respawn_tween = null
	_level_tween = null
## The real level the backdrop is dressed for (the palette uses LevelData.visual_level, the landmarks use the act).
var _backdrop_level: int = 1
var _card_plate: PanelContainer = null


## The plate shows exactly when the card text does (the transition code only ever drives the label).
func _process(_delta: float) -> void:
	if _card_plate != null and _transition_label != null:
		_card_plate.visible = _transition_label.visible and _transition_label.modulate.a > 0.01


## Waits up to `seconds`, ending early on a fresh press of jump or accept (never on a key that was already held).
func _wait_skippable(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
			return


## Freeze or release the current level's player (and with it the run clock).
func _set_player_locked(locked: bool) -> void:
	if _current_level_scene == null or not is_instance_valid(_current_level_scene):
		return
	var p = _current_level_scene.get_node_or_null("Player")
	if p == null or not p.has_method("lock_input"):
		return
	if locked:
		p.lock_input()
	else:
		p.unlock_input()


## PIP's line on the first level of each act ("" for every other level).
static func act_intro_line(level_number: int) -> String:
	match level_number:
		1: return "START SMALL, TREVOR. THE SPIRE DOES NOT FORGIVE, BUT IT DOES REPEAT."
		6: return "HEAT AHEAD. THE SPIRE IS WAKING UP."
		11: return "TEMPERATURE FALLING. WATCH THE ICE."
		16: return "STORM FRONT. EVERYTHING IS MOVING AT ONCE."
		21: return "I CAN SEE DAWN, TREVOR. DO NOT LOOK DOWN."
		26: return "THAT WAS NOT DAWN. THAT WAS THE ROOF. WELCOME TO THE PIPES."
		31: return "THE SKY IS CRACKING, TREVOR. KEEP YOUR EYES ON THE GROUND."
		36: return "THIS IS THE CORE. EVERYTHING BELOW IS YOURS TO LOSE."
		30: return "THE HIVE HUMS IN THE WALLS. NOBODY SENDS A MAZE TO A WEAK PLAYER, TREVOR. THEY SEND IT TO YOU."
		35: return "THE RIFT WARDEN IS THE HOLE BEHIND YOU. IT EATS THE SLOW. YOU ARE NOT SLOW."
		40: return "THIS IS THE LAST ONE. YOU CAME UP FROM THE BOTTOM. NOBODY ELSE DID."
	return ""


## The frame rate stayed low: offer (never force) a lower graphics preset.
func _on_quality_struggling(current: int, suggested: int) -> void:
	if get_node_or_null("QualityToast") != null:
		return
	var toast := QualityToast.new()
	toast.name = "QualityToast"
	toast.suggested = suggested
	add_child(toast)
	toast.answered.connect(func(lower_it: bool) -> void:
		var gs := get_node_or_null("/root/GameSettings")
		if lower_it and gs != null:
			gs.set_reg("gfx_quality", suggested, false)
			GraphicsQuality.apply(gs, suggested)
		var aq := get_node_or_null("AutoQuality") as AutoQuality
		if aq != null and lower_it:
			aq.reset_offer())


func _do_level_swap() -> void:
	_load_current_level()


func _on_level_completed() -> void:
	# Prevent double-triggers
	if _completion_pending:
		return
	_completion_pending = true

	# The tutorial ends back at the title; it is practice, never progress.
	var gm_t = get_node_or_null("/root/GameManager")
	if gm_t != null and gm_t.tutorial_active:
		_finish_tutorial()
		return

	var gm = get_node_or_null("/root/GameManager")
	# Capture BEFORE complete_current_level() advances it — is_game_complete()
	# reflects the persistent save history ("has level 25 ever been beaten"),
	# not "did this specific completion just finish the campaign", so it
	# stays true forever after the first clear and would wrongly fire on
	# every subsequent level's completion too.
	var game_complete: bool = gm != null and gm.current_level == LevelData.TOTAL_LEVELS and not gm.endless_active
	if gm != null:
		gm.complete_current_level()

	# Freeze player input
	if _current_level_scene != null:
		_current_level_scene.set("_level_complete", true)
		# Stop run timer
		_current_level_scene.set("_clock_running", false)
		# Freeze the player for real: input does nothing until the next level is clear.
		_hold_player = true
		_set_player_locked(true)

	# Play goal sound
	var audio = _find_audio()
	if audio != null and audio.has_method("play_goal"):
		audio.play_goal()

	# Show completion banner
	var hud = _current_level_scene.get_node_or_null("Hud")
	if hud != null:
		var banner = hud.get_node_or_null("Banner")
		if banner != null:
			var title_label = banner.get_node_or_null("Box/Title")
			if title_label != null:
				title_label.text = "ALL LEVELS COMPLETE" if game_complete else "LEVEL COMPLETE"
			var time_label = banner.get_node_or_null("Box/Time")
			if time_label != null and _current_level_scene != null:
				time_label.text = Hud.format_time(_current_level_scene.get("last_run_time"))
			# Finishing the last level currently existing is not the end of the
			# game — it is the end of what is BUILT. Saying so, and saying where
			# more is coming from, is the difference between an ending and a
			# player wondering whether something broke.
			if game_complete:
				_show_more_coming(banner)
				_show_ending()
			# The results card (ClearCard) inside the banner: the old floating text box is hidden.
			var box_old := banner.get_node_or_null("Box") as Control
			if box_old != null:
				box_old.visible = false
			var old_card := banner.get_node_or_null("ClearCard")
			if old_card != null:
				old_card.free()
			var card := ClearCard.new()
			card.name = "ClearCard"
			var lv_done := int(_current_level_scene.get("level_number"))
			var boss_lv := lv_done % 5 == 0
			card.headline = "ALL LEVELS COMPLETE" if game_complete else ("BOSS DEFEATED" if boss_lv else "LEVEL %d CLEARED" % lv_done)
			card.subtitle = String(LevelData.get_level(lv_done).name) if gm == null or not gm.endless_active else "ENDLESS"
			card.time_s = float(_current_level_scene.get("last_run_time"))
			card.attempts = int(_current_level_scene.get("attempts"))
			var got := 0
			if gm != null and gm.save_system != null:
				for i in SaveSystem.ORBS_PER_LEVEL:
					if gm.save_system.has_orb(lv_done, i):
						got += 1
			card.cores = got
			card.cores_max = SaveSystem.ORBS_PER_LEVEL if lv_done >= SaveSystem.FIRST_ORB_LEVEL else 0
			card.accent = Color(1.0, 0.45, 0.35) if boss_lv else Color(1.0, 0.83, 0.47)
			banner.add_child(card)
			banner.visible = true
			banner.modulate.a = 1.0

	# Finishing Level 25 has no "next level" to transition to — leave the
	# victory banner on screen instead of fading out and silently reloading
	# the level the player just won (that was the actual prior behavior:
	# current_level never advances past TOTAL_LEVELS, so _load_current_level()
	# would just reload Level 25 forever with no acknowledgment of the win).
	if game_complete:
		return

	# After banner delay, fade out and transition. process_always=false so this
	# timer pauses along with the fade tweens below — it defaults to true
	# (keeps ticking even while paused), which let the banner's hold time
	# silently drain in the background if the player opened the pause menu
	# during it, then jump straight to the fade-out the moment they unpaused.
	await _wait_skippable(completion_banner_time)

	# Close the NEXT level's act cover
	_hold_player = true
	var next_level: int = gm.current_level if gm != null else 1
	_fx.style = TransitionFx.style_for_level(next_level)
	_kill_transition_tweens()
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 1.0, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_fx, "cover", 1.0, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

	# the results card leaves with the old level
	if hud != null and is_instance_valid(hud):
		var b2 = hud.get_node_or_null("Banner")
		if b2 != null:
			b2.visible = false
	# Load next level (its player stays frozen until the screen is clear)
	_load_current_level()
	await get_tree().process_frame

	# The level card on the closed cover: act, number, name, one line. A fresh press skips it.
	_on_level_changed(next_level, true)
	_transition_label.text = _card_text
	_transition_label.visible = true
	_transition_label.modulate.a = 0.0
	tween = create_tween()
	tween.tween_property(_transition_label, "modulate:a", 1.0, 0.15)
	await tween.finished
	await _wait_skippable(level_card_hold)
	tween = create_tween()
	tween.tween_property(_transition_label, "modulate:a", 0.0, 0.15)
	await tween.finished
	_transition_label.visible = false

	# Open
	tween = create_tween()
	tween.tween_property(_transition_overlay, "color:a", 0.0, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_fx, "cover", 0.0, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	_hold_player = false
	_set_player_locked(false)


func _on_game_over() -> void:
	# Could show a game-over screen; for now restart from checkpoint
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.restart_from_checkpoint()


## Apply per-level color palette to the backdrop's sky gradient, ridges, and stars.
## Each act has a DRAMATICALLY different color signature for visual distinctiveness.
## Multiply a palette entry by the active theme's backdrop tint. Themes tint
## rather than replace so every Act keeps the identity it was designed with —
## Storm still reads as Storm under Ember, just warmer.
func _theme_tint(c: Color, tint: Color) -> Color:
	return Color(clampf(c.r * tint.r, 0.0, 1.0), clampf(c.g * tint.g, 0.0, 1.0),
		clampf(c.b * tint.b, 0.0, 1.0), c.a)


func _apply_level_colors(backdrop: Node, level_num: int) -> void:
	# Palette: [sky_top, sky_mid1, sky_mid2, sky_bottom, far_ridge, mid_ridge, near_ridge, star_color]
	#
	# DESIGN:
	#   Act I  (L1-5)   DAWN  — warm blue-orange, amber horizon, blue-white stars
	#   Act II (L6-10)  DUSK  — deep purple-magenta, amber-violet, warm stars
	#   Act III(L11-15) NIGHT — near-black, cold cyan accents, icy white stars
	#   Act IV (L16-20) STORM — dark blue-grey, electric teal, harsh blue stars
	#   Act V  (L21-25) APEX  — dark→warm gold progression, golden white stars

	var palettes := {
		# ══════════════════════════════════════════════════════════════
		# ACT I — DAWN / LEARN  (warm blue → orange horizon)
		# ══════════════════════════════════════════════════════════════
		1: [Color(0.03, 0.05, 0.12), Color(0.06, 0.08, 0.18),
			Color(0.14, 0.12, 0.18), Color(0.30, 0.22, 0.15),
			Color(0.08, 0.10, 0.16), Color(0.05, 0.07, 0.12),
			Color(0.03, 0.04, 0.08), Color(0.85, 0.90, 1.0)],
		2: [Color(0.03, 0.05, 0.13), Color(0.07, 0.09, 0.20),
			Color(0.16, 0.12, 0.18), Color(0.32, 0.20, 0.14),
			Color(0.09, 0.11, 0.17), Color(0.06, 0.07, 0.13),
			Color(0.03, 0.04, 0.09), Color(0.86, 0.91, 1.0)],
		3: [Color(0.04, 0.06, 0.14), Color(0.08, 0.10, 0.22),
			Color(0.18, 0.12, 0.18), Color(0.34, 0.20, 0.14),
			Color(0.10, 0.12, 0.18), Color(0.07, 0.08, 0.14),
			Color(0.04, 0.05, 0.10), Color(0.88, 0.92, 1.0)],
		4: [Color(0.04, 0.06, 0.12), Color(0.09, 0.09, 0.20),
			Color(0.20, 0.11, 0.16), Color(0.38, 0.22, 0.12),
			Color(0.11, 0.11, 0.17), Color(0.07, 0.07, 0.13),
			Color(0.04, 0.04, 0.09), Color(0.90, 0.93, 1.0)],
		5: [Color(0.05, 0.04, 0.10), Color(0.12, 0.07, 0.16),
			Color(0.24, 0.10, 0.16), Color(0.42, 0.22, 0.14),
			Color(0.13, 0.09, 0.14), Color(0.09, 0.06, 0.10),
			Color(0.05, 0.03, 0.07), Color(0.95, 0.82, 0.88)],

		# ══════════════════════════════════════════════════════════════
		# ACT II — DUSK / MASTER  (deep purple-magenta)
		# ══════════════════════════════════════════════════════════════
		6: [Color(0.06, 0.03, 0.12), Color(0.12, 0.06, 0.22),
			Color(0.20, 0.10, 0.28), Color(0.30, 0.15, 0.25),
			Color(0.12, 0.06, 0.16), Color(0.08, 0.04, 0.12),
			Color(0.05, 0.03, 0.08), Color(0.90, 0.78, 1.0)],
		7: [Color(0.07, 0.03, 0.13), Color(0.13, 0.06, 0.24),
			Color(0.22, 0.10, 0.30), Color(0.32, 0.16, 0.27),
			Color(0.13, 0.06, 0.17), Color(0.09, 0.04, 0.13),
			Color(0.05, 0.03, 0.09), Color(0.92, 0.80, 1.0)],
		8: [Color(0.08, 0.03, 0.12), Color(0.14, 0.06, 0.22),
			Color(0.23, 0.10, 0.28), Color(0.34, 0.16, 0.26),
			Color(0.14, 0.06, 0.16), Color(0.10, 0.04, 0.12),
			Color(0.06, 0.03, 0.08), Color(0.94, 0.82, 1.0)],
		9: [Color(0.09, 0.03, 0.11), Color(0.15, 0.06, 0.20),
			Color(0.24, 0.10, 0.26), Color(0.35, 0.16, 0.24),
			Color(0.15, 0.06, 0.15), Color(0.11, 0.04, 0.11),
			Color(0.06, 0.03, 0.07), Color(0.96, 0.84, 1.0)],
		10:[Color(0.10, 0.03, 0.10), Color(0.16, 0.06, 0.18),
			Color(0.25, 0.10, 0.24), Color(0.36, 0.16, 0.22),
			Color(0.16, 0.06, 0.14), Color(0.12, 0.04, 0.10),
			Color(0.07, 0.03, 0.06), Color(0.98, 0.86, 1.0)],

		# ══════════════════════════════════════════════════════════════
		# ACT III — NIGHT / SURVIVE  (near-black, cold cyan accents)
		# ══════════════════════════════════════════════════════════════
		11:[Color(0.02, 0.03, 0.06), Color(0.04, 0.06, 0.12),
			Color(0.08, 0.14, 0.22), Color(0.14, 0.20, 0.28),
			Color(0.04, 0.06, 0.10), Color(0.03, 0.04, 0.08),
			Color(0.02, 0.02, 0.05), Color(0.70, 0.90, 1.0)],
		12:[Color(0.02, 0.02, 0.05), Color(0.04, 0.05, 0.10),
			Color(0.06, 0.12, 0.20), Color(0.10, 0.18, 0.26),
			Color(0.04, 0.05, 0.09), Color(0.02, 0.03, 0.07),
			Color(0.01, 0.02, 0.04), Color(0.65, 0.88, 1.0)],
		13:[Color(0.01, 0.02, 0.04), Color(0.03, 0.04, 0.08),
			Color(0.05, 0.10, 0.18), Color(0.08, 0.16, 0.24),
			Color(0.03, 0.04, 0.08), Color(0.02, 0.03, 0.06),
			Color(0.01, 0.01, 0.03), Color(0.60, 0.85, 1.0)],
		14:[Color(0.01, 0.01, 0.03), Color(0.02, 0.03, 0.06),
			Color(0.04, 0.08, 0.16), Color(0.06, 0.14, 0.22),
			Color(0.02, 0.03, 0.06), Color(0.01, 0.02, 0.04),
			Color(0.01, 0.01, 0.02), Color(0.55, 0.82, 1.0)],
		15:[Color(0.02, 0.02, 0.04), Color(0.05, 0.04, 0.08),
			Color(0.12, 0.06, 0.16), Color(0.20, 0.10, 0.20),
			Color(0.05, 0.03, 0.08), Color(0.03, 0.02, 0.06),
			Color(0.02, 0.01, 0.03), Color(0.90, 0.75, 0.80)],

		# ══════════════════════════════════════════════════════════════
		# ACT IV — STORM / ENDURE  (dark blue-grey, electric teal)
		# ══════════════════════════════════════════════════════════════
		16:[Color(0.02, 0.03, 0.05), Color(0.04, 0.06, 0.10),
			Color(0.08, 0.12, 0.16), Color(0.12, 0.16, 0.18),
			Color(0.04, 0.06, 0.08), Color(0.03, 0.04, 0.06),
			Color(0.02, 0.02, 0.04), Color(0.50, 0.80, 0.95)],
		17:[Color(0.02, 0.03, 0.05), Color(0.04, 0.06, 0.09),
			Color(0.07, 0.11, 0.15), Color(0.11, 0.15, 0.17),
			Color(0.04, 0.05, 0.07), Color(0.03, 0.04, 0.05),
			Color(0.02, 0.02, 0.03), Color(0.45, 0.78, 0.92)],
		18:[Color(0.02, 0.02, 0.04), Color(0.03, 0.05, 0.08),
			Color(0.06, 0.10, 0.14), Color(0.10, 0.14, 0.16),
			Color(0.03, 0.05, 0.07), Color(0.02, 0.03, 0.05),
			Color(0.01, 0.02, 0.03), Color(0.40, 0.75, 0.90)],
		19:[Color(0.02, 0.02, 0.04), Color(0.03, 0.05, 0.08),
			Color(0.06, 0.10, 0.13), Color(0.10, 0.13, 0.15),
			Color(0.03, 0.05, 0.06), Color(0.02, 0.03, 0.04),
			Color(0.01, 0.02, 0.03), Color(0.38, 0.72, 0.88)],
		20:[Color(0.04, 0.02, 0.05), Color(0.08, 0.04, 0.10),
			Color(0.14, 0.06, 0.16), Color(0.22, 0.10, 0.20),
			Color(0.08, 0.04, 0.10), Color(0.05, 0.03, 0.08),
			Color(0.03, 0.02, 0.05), Color(0.92, 0.60, 0.70)],

		# ══════════════════════════════════════════════════════════════
		# ACT V — APEX / ASCEND  (dark → warm golden dawn progression)
		# ══════════════════════════════════════════════════════════════
		21:[Color(0.02, 0.02, 0.05), Color(0.04, 0.04, 0.10),
			Color(0.06, 0.06, 0.14), Color(0.10, 0.10, 0.18),
			Color(0.04, 0.04, 0.08), Color(0.03, 0.03, 0.06),
			Color(0.01, 0.02, 0.04), Color(0.75, 0.85, 1.0)],
		22:[Color(0.03, 0.03, 0.05), Color(0.06, 0.05, 0.10),
			Color(0.10, 0.08, 0.14), Color(0.16, 0.14, 0.16),
			Color(0.06, 0.05, 0.08), Color(0.04, 0.04, 0.06),
			Color(0.02, 0.03, 0.04), Color(0.80, 0.88, 1.0)],
		23:[Color(0.04, 0.04, 0.05), Color(0.08, 0.07, 0.10),
			Color(0.14, 0.12, 0.12), Color(0.24, 0.20, 0.14),
			Color(0.08, 0.06, 0.08), Color(0.05, 0.05, 0.06),
			Color(0.03, 0.04, 0.04), Color(0.88, 0.90, 1.0)],
		24:[Color(0.05, 0.04, 0.04), Color(0.10, 0.08, 0.08),
			Color(0.18, 0.14, 0.10), Color(0.32, 0.26, 0.14),
			Color(0.10, 0.08, 0.06), Color(0.07, 0.06, 0.05),
			Color(0.04, 0.04, 0.03), Color(0.92, 0.90, 0.85)],
		25:[Color(0.07, 0.05, 0.04), Color(0.16, 0.10, 0.06),
			Color(0.28, 0.18, 0.10), Color(0.44, 0.30, 0.16),
			Color(0.16, 0.10, 0.06), Color(0.12, 0.08, 0.05),
			Color(0.07, 0.05, 0.03), Color(1.0, 0.94, 0.82)],
	}
	var p: Array = palettes.get(level_num, palettes[1])

	# Run the whole palette through the active theme before anything reads it,
	# so a theme change recolours the sky, ridges, stars, particles and sky
	# body in one place instead of each consumer needing to know about themes.
	var gs_theme := get_node_or_null("/root/GameSettings")
	if gs_theme != null and gs_theme.has_method("get_theme"):
		var bg_tint: Color = gs_theme.get_theme()["bg"]
		if not bg_tint.is_equal_approx(Color(1, 1, 1)):
			var tinted: Array = []
			for entry in p:
				tinted.append(_theme_tint(entry, bg_tint))
			p = tinted

	# Update sky gradient
	var sky_rect = backdrop.get_node_or_null("Sky/SkyRect") as TextureRect
	if sky_rect != null and sky_rect.texture is GradientTexture2D:
		var grad_tex := sky_rect.texture as GradientTexture2D
		if grad_tex.gradient != null:
			for i in mini(grad_tex.gradient.get_point_count(), 4):
				grad_tex.gradient.set_color(i, p[i])

	# Layer colours by depth from the horizon colour (p[3]): the farthest layer is lightest and each nearer one
	# darker. The old palette ridges were all within a few percent of the sky, so the fills vanished and only
	# their thin rim lines showed: mountains drawn as wireframe. Graded layers read as real distance.
	var horizon: Color = p[3]
	var night: Color = p[0]
	var depth_tone := func(k: float) -> Color:
		var c := horizon.lerp(night.darkened(0.55), k)
		return Color(c.r, c.g, c.b, 1.0)
	var far = backdrop.get_node_or_null("FarRidge/Poly")
	if far != null and far is Polygon2D:
		(far as Polygon2D).color = depth_tone.call(0.42)
	var mid = backdrop.get_node_or_null("MidRidge/Poly")
	if mid != null and mid is Polygon2D:
		(mid as Polygon2D).color = depth_tone.call(0.66)
	var near = backdrop.get_node_or_null("NearRidge/Poly")
	if near != null and near is Polygon2D:
		(near as Polygon2D).color = depth_tone.call(0.86)

	# Update star color
	var stars_field = backdrop.get_node_or_null("Stars/Field")
	if stars_field != null and stars_field is StarField:
		(stars_field as StarField).star_color = p[7]

	# The biome's landmark skyline (see CitySilhouette): what stands on the horizon of this act.
	var act_real: int = clampi((_backdrop_level - 1) / 5, 0, 7)
	var styles := ["towers", "cranes", "shards", "rods", "chimneys", "pipes", "shards", "core"]
	var lights := [Color(1.0, 0.85, 0.5), Color(1.0, 0.6, 0.25), Color(0.6, 0.9, 1.0), Color(0.6, 0.85, 1.0),
		Color(1.0, 0.55, 0.2), Color(0.4, 0.95, 0.85), Color(0.8, 0.6, 1.0), Color(1.0, 0.4, 0.3)]
	var far_city = backdrop.get_node_or_null("FarCity/Silhouette") as Polygon2D
	if far_city != null:
		far_city.color = depth_tone.call(0.30)
	var mid_city = backdrop.get_node_or_null("MidCity/Silhouette") as Polygon2D
	if mid_city != null:
		mid_city.color = depth_tone.call(0.55)
	for city in [far_city, mid_city]:
		var cs := city as CitySilhouette
		if cs == null:
			continue
		cs.style = String(styles[act_real])
		cs.add_windows = true
		var lc: Color = lights[act_real]
		cs.window_color = Color(lc.r, lc.g, lc.b, 0.55 if cs == far_city else 0.8)
		if cs.style in ["cranes", "rods", "chimneys"]:
			cs.building_width = 46.0
		elif cs.style in ["shards", "core"]:
			cs.building_width = 120.0

	# Vary each backdrop layer's shape per level, not just its color — every
	# level previously shared one baked skyline/ridge/star layout from
	# backdrop.tscn, so only the palette ever changed. Seeds are derived
	# from level_num with distinct offsets per layer so the layers don't all
	# reshape in lockstep (which would still read as "one" repeated shape).
	var far_city_shape := far_city as CitySilhouette
	if far_city_shape != null:
		far_city_shape.rng_seed = level_num * 7919 + 1
		far_city_shape._rebuild()
	var mid_city_shape := mid_city as CitySilhouette
	if mid_city_shape != null:
		mid_city_shape.rng_seed = level_num * 7919 + 2
		mid_city_shape._rebuild()
	# StarField/ParallaxRidge already auto-rebuild from an inline rng_seed
	# setter — no manual _rebuild() call needed for these.
	if stars_field != null and stars_field is StarField:
		(stars_field as StarField).rng_seed = level_num * 7919 + 3
	if far != null and far is ParallaxRidge:
		(far as ParallaxRidge).rng_seed = level_num * 7919 + 4
	if mid != null and mid is ParallaxRidge:
		(mid as ParallaxRidge).rng_seed = level_num * 7919 + 5
	if near != null and near is ParallaxRidge:
		(near as ParallaxRidge).rng_seed = level_num * 7919 + 6

	# Update floating particles — match star color with lower alpha
	var gs = get_node_or_null("/root/GameSettings")
	var particles_visible = gs == null or gs.floating_particles
	var particles1 = backdrop.get_node_or_null("Particles1") as FloatingParticles
	if particles1 != null:
		particles1.particle_color = Color(p[7].r, p[7].g, p[7].b, 0.3)
		particles1.visible = particles_visible
		particles1.z_index = BACKDROP_Z
	var particles2 = backdrop.get_node_or_null("Particles2") as FloatingParticles
	if particles2 != null:
		particles2.particle_color = Color(p[7].r, p[7].g, p[7].b, 0.2)
		particles2.visible = particles_visible
		particles2.z_index = BACKDROP_Z
	_apply_parallax_settings(backdrop, gs)
	_apply_sky_identity(backdrop, level_num, p)
	_apply_foreground(backdrop, level_num, p)

	# Neon Glow dial: scale the lit strip and glow line on every platform.
	if gs != null and "glow_intensity" in gs:
		_apply_glow_intensity(clampf(gs.glow_intensity, 0.0, 1.0))



## Re-apply the FX dials to the level already on screen. Cheap enough to run on
## every settings change: it walks six parallax layers and the terrain's edge
## colours, nothing more.
func _on_fx_settings_changed() -> void:
	var gs := get_node_or_null("/root/GameSettings")
	if gs == null:
		return
	var backdrop := _find_backdrop()
	if backdrop != null:
		_apply_parallax_settings(backdrop, gs)
	if "glow_intensity" in gs:
		_apply_glow_intensity(clampf(gs.glow_intensity, 0.0, 1.0))


## The Backdrop lives inside whichever level is currently loaded.
func _find_backdrop() -> Node:
	if _level_container == null:
		return null
	for child in _level_container.get_children():
		var b := child.get_node_or_null("Backdrop")
		if b != null:
			return b
	return null



## Give each Act an unmistakable sky: a celestial landmark plus weather.
##
## This is the fix for "every level looks the same". The palettes below already
## varied per level, but colour alone reads as one place lit differently — the
## eye needs a landmark and some motion to believe it has travelled. Act IV in
## particular is *named* Storm and had no weather whatsoever.
##
## Driven entirely by the table here, so adding an Act is a table entry rather
## than new code. `p` is the level's palette; sky bodies and weather borrow from
## it so they never fight the gradient behind them.
func _apply_sky_identity(backdrop: Node, level_num: int, p: Array) -> void:
	var act: int = clampi((level_num - 1) / 5, 0, 4)

	# body kind, radius, screen-ish offset, body colour, glow colour
	var bodies := [
		# Act I — Dawn: a low rising sun, warm, near the horizon.
		{"kind": SkyBody.Kind.SUN, "r": 120.0, "pos": Vector2(1500, 210),
			"col": Color(1.0, 0.86, 0.62), "glow": Color(1.0, 0.62, 0.30, 0.55)},
		# Act II — Dusk: a big low moon, faintly warm from the last light.
		{"kind": SkyBody.Kind.MOON, "r": 105.0, "pos": Vector2(560, 190),
			"col": Color(0.98, 0.92, 0.88), "glow": Color(1.0, 0.72, 0.85, 0.42)},
		# Act III — Night: a small high moon, cold and distant.
		{"kind": SkyBody.Kind.MOON, "r": 68.0, "pos": Vector2(1750, 120),
			"col": Color(0.90, 0.94, 1.0), "glow": Color(0.55, 0.72, 1.0, 0.40)},
		# Act IV — Storm: a bruised planet mostly lost behind the weather.
		{"kind": SkyBody.Kind.PLANET, "r": 145.0, "pos": Vector2(420, 165),
			"col": Color(0.40, 0.45, 0.62), "glow": Color(0.45, 0.62, 0.95, 0.34)},
		# Act V — Apex: a huge sun cresting the horizon. Dawn breaks.
		{"kind": SkyBody.Kind.SUN, "r": 185.0, "pos": Vector2(1250, 265),
			"col": Color(1.0, 0.90, 0.66), "glow": Color(1.0, 0.70, 0.28, 0.62)},
	]
	var weathers := [
		{"kind": Weather.Kind.NONE, "n": 0, "tint": Color(1, 1, 1, 0)},
		{"kind": Weather.Kind.SNOW, "n": 55, "tint": Color(1.0, 0.92, 0.96, 0.30)},
		{"kind": Weather.Kind.SNOW, "n": 80, "tint": Color(0.86, 0.93, 1.0, 0.34)},
		{"kind": Weather.Kind.RAIN, "n": 150, "tint": Color(0.66, 0.80, 1.0, 0.40)},
		{"kind": Weather.Kind.EMBERS, "n": 70, "tint": Color(1.0, 0.62, 0.28, 0.55)},
	]

	var body_cfg: Dictionary = bodies[act]
	var sky := backdrop.get_node_or_null("Sky")
	if sky != null:
		var existing := sky.get_node_or_null("SkyBody")
		if existing != null:
			existing.free()
		var body := SkyBody.new()
		body.name = "SkyBody"
		body.kind = body_cfg["kind"]
		body.radius = body_cfg["r"]
		body.body_color = body_cfg["col"]
		body.glow_color = body_cfg["glow"]
		# Per-level seed so two levels in the same Act do not share a moon face.
		body.detail_seed = level_num * 977 + 13
		# Nudge across the sky per level within the Act, so consecutive levels
		# differ in composition and not only in hue.
		var within: int = (level_num - 1) % 5
		body.position = body_cfg["pos"] + Vector2(float(within - 2) * 95.0,
			float(within % 2) * 26.0)
		sky.add_child(body)
		# Behind the SkyRect gradient would hide it; in front of it, but the Sky
		# CanvasLayer still sits behind every gameplay layer.
		sky.move_child(body, sky.get_child_count() - 1)

	var w_cfg: Dictionary = weathers[act]
	var existing_w := backdrop.get_node_or_null("Weather")
	if existing_w != null:
		existing_w.free()
	if w_cfg["kind"] != Weather.Kind.NONE:
		var w := Weather.new()
		w.name = "Weather"
		w.tint = w_cfg["tint"]
		w.particle_count = w_cfg["n"]
		w.kind = w_cfg["kind"]
		# In front of the ridges so it reads as falling through the scene,
		# behind the player (z 2) so it never obscures the character.
		w.z_index = 1
		backdrop.add_child(w)



## A near silhouette layer that passes IN FRONT of the player.
##
## Every existing backdrop layer sits behind the action, which is why frames
## read flat no matter how the palette changes — there is nothing to establish
## that the player occupies a middle distance. One dark foreground ridge
## scrolling faster than the camera fixes that in a single layer, and it costs
## one polygon.
##
## Drawn very dark and slightly transparent so it never obscures a platform
## the player has to read: it frames the shot, it does not compete with it.
func _apply_foreground(backdrop: Node, level_num: int, p: Array) -> void:
	var existing := backdrop.get_node_or_null("Foreground")
	if existing != null:
		existing.free()

	var layer := Parallax2D.new()
	layer.name = "Foreground"
	# Horizontally >1, so it still moves faster than the camera and reads as
	# the nearest layer. VERTICALLY it must be exactly 1.0.
	#
	# This was 1.10, and in a game whose whole subject is climbing that is a
	# bug: a vertical scale above 1 means the layer rises FASTER than the world
	# does. Over a 2000px ascent this large dark ridge polygon drifted 200px up
	# relative to the terrain and swept into the play area as a black shape
	# crossing the screen. Locked to 1.0 it stays where it was authored — at
	# the bottom of the level — and simply falls out of view as the player
	# climbs, which is what a ground-level silhouette should do.
	layer.scroll_scale = Vector2(1.30, 1.0)
	layer.repeat_size = Vector2(2400, 0)
	layer.repeat_times = 3
	# BEHIND the terrain, not in front of it.
	#
	# This was z_index 4 — above both the platforms (0) and the player (2) —
	# which meant a decorative ridge could sit on top of a platform the player
	# has to read and land on. In a precision platformer, nothing decorative
	# may ever occlude gameplay geometry: the lit platform edge is the single
	# most load-bearing readability cue in the game. It still scrolls faster
	# than the camera, so it still reads as the nearest layer; it just no
	# longer hides the thing you are trying to jump onto.
	layer.z_index = BACKDROP_Z
	backdrop.add_child(layer)

	var rng := RandomNumberGenerator.new()
	rng.seed = level_num * 5153 + 71

	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var width := 2400.0
	var base_y := 1050.0
	var steps := 16
	pts.append(Vector2(0, base_y + 400.0))
	for i in steps + 1:
		var x := width * float(i) / float(steps)
		# Two summed sines plus jitter: a single sine reads as a wave, and pure
		# noise reads as static. This gives a believable ridgeline.
		var h := sin(float(i) * 0.9 + float(level_num)) * 70.0 			+ sin(float(i) * 0.37 + float(level_num) * 2.1) * 130.0 			+ rng.randf_range(-35.0, 35.0)
		pts.append(Vector2(x, base_y - 120.0 + h))
	pts.append(Vector2(width, base_y + 400.0))
	poly.polygon = pts

	# Derived from the level's own near-ridge colour so it always belongs to
	# the palette, then pushed much darker to sit closest to the eye.
	var near: Color = p[6]
	poly.color = Color(near.r * 0.55, near.g * 0.55, near.b * 0.62, 0.7)
	layer.add_child(poly)


## The backdrop's parallax layers, by name. These are `Parallax2D` nodes sitting
## directly under Backdrop — there is no container node grouping them.
##
## This list exists because both parallax settings were dead for their entire
## shipped life: the old code did `backdrop.get_node_or_null("Parallax")`, and no
## node by that name has ever existed, so the lookup always returned null. The
## Background Motion toggle therefore never did anything, and the newer Parallax
## Depth slider inherited the same broken lookup plus a wrong type check
## (`ParallaxLayer`, when these are `Parallax2D`).
const PARALLAX_LAYERS: Array[String] = [
	"Stars", "FarCity", "FarRidge", "MidCity", "MidRidge", "NearRidge",
]
## Draw level of every sky layer (see _apply_parallax_settings). Level back walls use BACKDROP_Z + 1.
const BACKDROP_Z := -3


## Apply Background Motion (on/off) and Parallax Depth (0-100%) to the real
## layers. Depth scales each layer's `scroll_scale` toward 1.0 — locked to the
## camera, i.e. no apparent parallax — so 0% reads as a flat backdrop rather
## than one racing along with the world.
func _apply_parallax_settings(backdrop: Node, gs) -> void:
	if backdrop == null:
		return
	var motion_on: bool = gs == null or gs.bg_motion
	var depth: float = 1.0
	if gs != null and "parallax_intensity" in gs:
		depth = clampf(gs.parallax_intensity, 0.0, 1.0)
	if not motion_on:
		depth = 0.0

	for layer_name in PARALLAX_LAYERS:
		var layer := backdrop.get_node_or_null(NodePath(layer_name)) as Parallax2D
		if layer == null:
			continue
		# The sky sits two draw levels down, so a level's own back walls (z -1) cover it while the level's
		# ground and platforms (z 0) stay in front of those walls. With the sky at z 0 the walls had to be
		# drawn over everything, and they hid the level 10 shaft floor.
		layer.z_index = BACKDROP_Z
		# Capture the scene-authored scroll once, so repeated applications
		# scale from the original rather than compounding on themselves.
		if not layer.has_meta("base_scroll"):
			layer.set_meta("base_scroll", layer.scroll_scale)
		var base: Vector2 = layer.get_meta("base_scroll")
		layer.scroll_scale = base.lerp(Vector2.ONE, 1.0 - depth)


## Fade every platform's edge highlight toward its unlit body colour. The
## edge strip is this game's single most load-bearing readability cue (it is
## what tells you which faces you can land on), so the dial floors at a
## still-visible 25% rather than allowing it to be turned off entirely.
func _apply_glow_intensity(amount: float) -> void:
	var level := get_node_or_null("LevelContainer")
	if level == null:
		return
	var terrain = level.get_node_or_null("Main/Terrain")
	if terrain == null:
		return
	var strength: float = lerpf(0.25, 1.0, amount)
	# The active theme's edge tint rides along with the glow pass, since both
	# repaint the same property and doing them separately would have one
	# clobber the other.
	var edge_tint := Color(1, 1, 1)
	var gs_t := get_node_or_null("/root/GameSettings")
	if gs_t != null and gs_t.has_method("get_theme"):
		edge_tint = gs_t.get_theme()["edge"]
	for platform in terrain.get_children():
		var glow := platform.get_node_or_null("GlowLine") as Polygon2D
		if glow != null:
			var c := glow.color
			glow.color = Color(c.r, c.g, c.b, 0.15 * strength)
		if "edge_color" in platform and "color" in platform:
			if not platform.has_meta("base_edge"):
				platform.set_meta("base_edge", platform.edge_color)
			var base_edge: Color = platform.get_meta("base_edge")
			platform.edge_color = _theme_tint(
				platform.color.lerp(base_edge, strength), edge_tint)


## The menu pauses the tree, which is correct for a player and fatal for a test
## harness: a suite that boots this scene and waits for the level to advance
## would wait forever. So it is shown only for an actual play session.
##
## --skip-menu is the launcher's flag (someone who already clicked Play there
## should not click it again). A --script run is a test driving the game, and a
## headless run has nobody to click PLAY.
func _should_show_start_menu() -> bool:
	var args := OS.get_cmdline_args()
	if "--skip-menu" in args or "--script" in args:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return true


## Back to the title screen without losing the run: the game is left exactly as
## it was and PLAY there resumes it. Used by the corner home icon and the pause
## menu's MAIN MENU entry.
func go_home() -> void:
	if get_node_or_null("StartMenu") != null:
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.is_paused = false
		if gm.pause_menu != null:
			gm.pause_menu.visible = false
	_show_start_menu()


func _show_start_menu() -> void:
	if get_node_or_null("StartMenu") != null:
		return
	var menu := StartMenu.new()
	menu.name = "StartMenu"
	add_child(menu)


## The ending screen: what the gate does depends on the cores banked.
func _show_ending() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or gm.save_system == null:
		return
	await get_tree().create_timer(1.6, false).timeout
	if get_node_or_null("EndingScreen") != null:
		return
	var ending := EndingScreen.new()
	ending.name = "EndingScreen"
	ending.total = gm.save_system.orb_total()
	ending.goal = SaveSystem.ORB_GOAL
	add_child(ending)
	# HOME SCREEN and RESET PROGRESS come back as requests; the game acts on them here.
	ending.home_requested.connect(func():
		go_home())
	ending.reset_requested.connect(func():
		var gm_reset := get_node_or_null("/root/GameManager")
		if gm_reset != null:
			gm_reset.reset_progress()
		go_home())
	# After the ending: the "next part is coming" card.
	ending.closed.connect(func():
		if get_node_or_null("ComingSoon") != null:
			return
		var soon := ComingSoon.new()
		soon.name = "ComingSoon"
		add_child(soon))


## The end-of-content note, shown once the player clears the last level that
## exists. More levels are planned (25 of an eventual 100), and a player who
## reaches the end deserves to be told that rather than left guessing.
func _show_more_coming(banner: Node) -> void:
	var box := banner.get_node_or_null("Box")
	if box == null or box.get_node_or_null("MoreComing") != null:
		return
	var label := Label.new()
	label.name = "MoreComing"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(420, 0)
	label.add_theme_font_size_override("font_size", UITheme.sz(15))
	label.add_theme_color_override("font_color", Color(0.62, 0.70, 0.82))
	label.text = ("THAT IS EVERY LEVEL BUILT SO FAR.
"
		+ "MORE ARE COMING - 25 OF AN EVENTUAL 100.

"
		+ "FOUND A JUMP THAT FELT IMPOSSIBLE, OR ONE THAT FELT GREAT?
"
		+ "TELL THE DEVELOPER: github.com/p4inz-code/project-ascent")
	box.add_child(label)
