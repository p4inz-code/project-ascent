extends Node2D
## Main game scene that manages level loading, transitions, pause overlay,
## and the overall game flow.
##
## This replaces main_scene.tscn as the entry point. It loads the current
## level as a child and overlays the pause menu.

## Time the completion banner is visible before the fade-out begins (s).
@export var completion_banner_time: float = 2.4
## Time to fade to black before the next level loads (s).
@export var fade_out_time: float = 0.4
## Time the level-name card is visible before fading in (s).
@export var level_card_hold: float = 1.2
## Time to fade from black back to gameplay (s).
@export var fade_in_time: float = 0.4

var _current_level_scene: Node2D = null
var _pause_menu: CanvasLayer = null
var _level_container: Node2D
var _transition_overlay: ColorRect
var _transition_label: Label
var _transitioning: bool = false
var _completion_pending: bool = false


func _ready() -> void:
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
	_transition_label = Label.new()
	_transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_transition_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_label.add_theme_font_size_override("font_size", 44)
	_transition_label.add_theme_color_override("font_color", Color(0.20, 0.70, 1.0))
	_transition_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.35, 0.70, 0.6))
	_transition_label.add_theme_constant_override("shadow_offset_x", 0)
	_transition_label.add_theme_constant_override("shadow_offset_y", 3)
	_transition_label.visible = false
	canvas.add_child(_transition_label)

	# Load pause menu
	var pause_scene := load("res://scenes/pause_menu.tscn") as PackedScene
	if pause_scene != null:
		_pause_menu = pause_scene.instantiate()
		add_child(_pause_menu)

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

	# Stop any existing audio before clearing the level
	var old_audio = _find_audio()
	if old_audio != null:
		if old_audio.has_method("stop_wall_slide"):
			old_audio.stop_wall_slide()

	# Clear existing level
	for child in _level_container.get_children():
		child.queue_free()
	await get_tree().process_frame  # Let queue_free complete

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
		_apply_level_colors(backdrop, level_num)

	# Connect level completion
	if _current_level_scene.has_signal("level_completed"):
		_current_level_scene.level_completed.connect(_on_level_completed)


func _find_audio():
	if _current_level_scene != null and is_instance_valid(_current_level_scene):
		return _current_level_scene.get_node_or_null("Audio")
	return null


func _on_level_changed(level_number: int) -> void:
	# Clear any pending completion state
	_completion_pending = false

	# If restarting the same level, skip the full transition animation
	if _current_level_scene != null and _current_level_scene.get("level_number") == level_number:
		_load_current_level()
		return

	# Show level card (name + number) during fade-in
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
	var act := ""
	if level_number <= 5: act = "ACT I — LEARN"
	elif level_number <= 10: act = "ACT II — MASTER"
	elif level_number <= 15: act = "ACT III — SURVIVE"
	elif level_number <= 20: act = "ACT IV — ENDURE"
	else: act = "ACT V — ASCEND"
	_transition_label.text = "%s\n\nLEVEL %d — %s\n\n%s" % [act, level_number, level_def.name, subtitle]
	_transition_label.visible = true
	_transition_label.modulate.a = 0.0

	# Fade in overlay, show level card, then fade out
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 1.0, fade_out_time)
	tween.tween_property(_transition_label, "modulate:a", 1.0, 0.2)
	tween.tween_callback(_do_level_swap)
	tween.tween_interval(level_card_hold)
	tween.tween_property(_transition_label, "modulate:a", 0.0, 0.2)
	tween.tween_property(_transition_overlay, "color:a", 0.0, fade_in_time)
	tween.tween_callback(func() -> void:
		_transition_label.visible = false
		_transitioning = false
	)


func _do_level_swap() -> void:
	_load_current_level()


func _on_level_completed() -> void:
	# Prevent double-triggers
	if _completion_pending:
		return
	_completion_pending = true

	var gm = get_node_or_null("/root/GameManager")
	# Capture BEFORE complete_current_level() advances it — is_game_complete()
	# reflects the persistent save history ("has level 25 ever been beaten"),
	# not "did this specific completion just finish the campaign", so it
	# stays true forever after the first clear and would wrongly fire on
	# every subsequent level's completion too.
	var game_complete: bool = gm != null and gm.current_level == LevelData.TOTAL_LEVELS
	if gm != null:
		gm.complete_current_level()

	# Freeze player input
	if _current_level_scene != null:
		_current_level_scene.set("_level_complete", true)
		# Stop run timer
		_current_level_scene.set("_clock_running", false)
		# Freeze player
		var player = _current_level_scene.get_node_or_null("Player")
		if player != null:
			player.set("velocity", Vector2.ZERO)

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
			banner.visible = true
			banner.modulate.a = 0.0
			var tween = create_tween()
			tween.tween_property(banner, "modulate:a", 1.0, 0.3)

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
	await get_tree().create_timer(completion_banner_time, false).timeout

	# Fade to black
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 1.0, fade_out_time)
	await tween.finished

	# Load next level
	_load_current_level()

	# Fade in
	tween = create_tween()
	tween.tween_property(_transition_overlay, "color:a", 0.0, fade_in_time)
	await tween.finished


func _on_game_over() -> void:
	# Could show a game-over screen; for now restart from checkpoint
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.restart_from_checkpoint()


## Apply per-level color palette to the backdrop's sky gradient, ridges, and stars.
## Each act has a DRAMATICALLY different color signature for visual distinctiveness.
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

	# Update sky gradient
	var sky_rect = backdrop.get_node_or_null("Sky/SkyRect") as TextureRect
	if sky_rect != null and sky_rect.texture is GradientTexture2D:
		var grad_tex := sky_rect.texture as GradientTexture2D
		if grad_tex.gradient != null:
			for i in mini(grad_tex.gradient.get_point_count(), 4):
				grad_tex.gradient.set_color(i, p[i])

	# Update ridge colors
	var far = backdrop.get_node_or_null("FarRidge/Poly")
	if far != null and far is Polygon2D:
		(far as Polygon2D).color = p[4]
	var mid = backdrop.get_node_or_null("MidRidge/Poly")
	if mid != null and mid is Polygon2D:
		(mid as Polygon2D).color = p[5]
	var near = backdrop.get_node_or_null("NearRidge/Poly")
	if near != null and near is Polygon2D:
		(near as Polygon2D).color = p[6]

	# Update star color
	var stars_field = backdrop.get_node_or_null("Stars/Field")
	if stars_field != null and stars_field is StarField:
		(stars_field as StarField).star_color = p[7]

	# Update city silhouettes — darker for later acts
	var far_city = backdrop.get_node_or_null("FarCity/Silhouette") as Polygon2D
	if far_city != null:
		var base: Color = p[4]
		far_city.color = Color(base.r * 0.6, base.g * 0.6, base.b * 0.7, 0.5)
	var mid_city = backdrop.get_node_or_null("MidCity/Silhouette") as Polygon2D
	if mid_city != null:
		var base2: Color = p[5]
		mid_city.color = Color(base2.r * 0.5, base2.g * 0.5, base2.b * 0.6, 0.7)

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
	var particles2 = backdrop.get_node_or_null("Particles2") as FloatingParticles
	if particles2 != null:
		particles2.particle_color = Color(p[7].r, p[7].g, p[7].b, 0.2)
		particles2.visible = particles_visible
	# Control parallax/background motion
	var bg_motion = gs == null or gs.bg_motion
	var parallax = backdrop.get_node_or_null("Parallax")
	if parallax != null:
		parallax.process_mode = Node.PROCESS_MODE_INHERIT if bg_motion else Node.PROCESS_MODE_DISABLED
		# Parallax Depth dial: scale each layer's motion factor rather than
		# only switching motion on and off, so "subtle background" is a
		# reachable choice and not just all-or-nothing.
		if bg_motion and gs != null and "parallax_intensity" in gs:
			var depth: float = clampf(gs.parallax_intensity, 0.0, 1.0)
			for layer in parallax.get_children():
				if layer is ParallaxLayer:
					if not layer.has_meta("base_scroll"):
						layer.set_meta("base_scroll", layer.motion_scale)
					var base: Vector2 = layer.get_meta("base_scroll")
					# Lerp toward 1.0 (locked to the camera = no apparent
					# parallax) so 0% reads as a flat backdrop, not a
					# backdrop that scrolls at full speed with the world.
					layer.motion_scale = base.lerp(Vector2.ONE, 1.0 - depth)

	# Neon Glow dial: scale the lit strip and glow line on every platform.
	if gs != null and "glow_intensity" in gs:
		_apply_glow_intensity(clampf(gs.glow_intensity, 0.0, 1.0))


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
	for platform in terrain.get_children():
		var glow := platform.get_node_or_null("GlowLine") as Polygon2D
		if glow != null:
			var c := glow.color
			glow.color = Color(c.r, c.g, c.b, 0.15 * strength)
		if "edge_color" in platform and "color" in platform:
			if not platform.has_meta("base_edge"):
				platform.set_meta("base_edge", platform.edge_color)
			var base_edge: Color = platform.get_meta("base_edge")
			platform.edge_color = platform.color.lerp(base_edge, strength)
