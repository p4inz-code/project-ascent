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
	_transition_label.add_theme_font_size_override("font_size", 48)
	_transition_label.add_theme_color_override("font_color", Color(1, 0.827, 0.471))
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
		3: subtitle = "Master the wall"
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
	_transition_label.text = "LEVEL %d\n%s\n\n%s" % [level_number, level_def.name, subtitle]
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

	# Save progress immediately — this is the critical persistence step
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.complete_current_level()

	# Pause gameplay input (main_scene._level_complete = true already blocks
	# _physics_process, but we also freeze the tree for extra safety)
	get_tree().paused = true

	# After the completion banner finishes, do the transition
	await get_tree().create_timer(completion_banner_time).timeout

	# Resume tree just long enough for the transition to play
	get_tree().paused = false

	# If game is complete, show victory instead of transitioning
	if gm != null and gm.save_system.is_game_complete():
		_show_victory()
		return

	# Transition to the next level
	if gm != null:
		_on_level_changed(gm.current_level)


func _show_victory() -> void:
	_transitioning = true
	_transition_label.text = "ALL LEVELS CLEARED\n\nThe ascent is complete.\n\nCongratulations!"
	_transition_label.visible = true
	_transition_label.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 1.0, fade_out_time)
	tween.tween_property(_transition_label, "modulate:a", 1.0, 0.3)
	# After victory card, restart from checkpoint
	tween.tween_interval(3.0)
	tween.tween_property(_transition_label, "modulate:a", 0.0, 0.3)
	tween.tween_property(_transition_overlay, "color:a", 0.0, fade_in_time)
	tween.tween_callback(func() -> void:
		_transition_label.visible = false
		_transitioning = false
		_completion_pending = false
		var gm := get_node_or_null("/root/GameManager")
		if gm != null:
			gm.restart_from_checkpoint()
	)


func _on_game_over() -> void:
	# Could show a game-over screen; for now restart from checkpoint
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.restart_from_checkpoint()


## Apply per-level color palette to the backdrop's sky gradient, ridges, and stars.
func _apply_level_colors(backdrop: Node, level_num: int) -> void:
	# Level palettes: [sky_top, sky_mid1, sky_mid2, sky_bottom, far_ridge, mid_ridge, near_ridge, star]
	var palettes := {
		# Act I — Foundation
		1: [Color(0.04, 0.05, 0.09), Color(0.08, 0.10, 0.17),
			Color(0.16, 0.18, 0.26), Color(0.25, 0.25, 0.30),
			Color(0.11, 0.12, 0.19), Color(0.08, 0.09, 0.14),
			Color(0.05, 0.06, 0.09), Color(0.78, 0.85, 1.0)],
		2: [Color(0.04, 0.05, 0.10), Color(0.08, 0.10, 0.18),
			Color(0.17, 0.19, 0.28), Color(0.26, 0.26, 0.32),
			Color(0.11, 0.13, 0.20), Color(0.08, 0.09, 0.15),
			Color(0.05, 0.06, 0.10), Color(0.78, 0.85, 1.0)],
		3: [Color(0.05, 0.06, 0.11), Color(0.10, 0.12, 0.20),
			Color(0.19, 0.21, 0.30), Color(0.28, 0.28, 0.34),
			Color(0.12, 0.14, 0.21), Color(0.09, 0.10, 0.16),
			Color(0.05, 0.06, 0.10), Color(0.80, 0.87, 1.0)],
		4: [Color(0.05, 0.05, 0.10), Color(0.10, 0.10, 0.19),
			Color(0.20, 0.18, 0.28), Color(0.30, 0.27, 0.34),
			Color(0.13, 0.12, 0.20), Color(0.09, 0.08, 0.15),
			Color(0.05, 0.05, 0.10), Color(0.82, 0.86, 1.0)],
		5: [Color(0.06, 0.04, 0.08), Color(0.12, 0.08, 0.14),
			Color(0.22, 0.14, 0.20), Color(0.32, 0.22, 0.28),
			Color(0.14, 0.10, 0.16), Color(0.10, 0.07, 0.12),
			Color(0.06, 0.04, 0.08), Color(0.90, 0.80, 0.85)],
		# Act II — Mastery
		6: [Color(0.05, 0.06, 0.12), Color(0.10, 0.12, 0.22),
			Color(0.20, 0.22, 0.32), Color(0.30, 0.30, 0.38),
			Color(0.13, 0.15, 0.23), Color(0.10, 0.11, 0.18),
			Color(0.06, 0.07, 0.12), Color(0.80, 0.88, 1.0)],
		7: [Color(0.05, 0.05, 0.11), Color(0.10, 0.11, 0.21),
			Color(0.21, 0.20, 0.30), Color(0.31, 0.29, 0.37),
			Color(0.14, 0.13, 0.22), Color(0.10, 0.10, 0.17),
			Color(0.06, 0.06, 0.11), Color(0.82, 0.86, 1.0)],
		8: [Color(0.06, 0.05, 0.10), Color(0.11, 0.10, 0.20),
			Color(0.22, 0.19, 0.29), Color(0.32, 0.28, 0.36),
			Color(0.15, 0.13, 0.21), Color(0.11, 0.09, 0.16),
			Color(0.07, 0.06, 0.10), Color(0.84, 0.85, 1.0)],
		9: [Color(0.06, 0.04, 0.09), Color(0.12, 0.09, 0.18),
			Color(0.23, 0.17, 0.27), Color(0.33, 0.25, 0.33),
			Color(0.15, 0.12, 0.19), Color(0.11, 0.08, 0.15),
			Color(0.07, 0.05, 0.09), Color(0.88, 0.82, 0.92)],
		10: [Color(0.07, 0.04, 0.08), Color(0.13, 0.08, 0.15),
			Color(0.24, 0.14, 0.22), Color(0.35, 0.22, 0.30),
			Color(0.16, 0.10, 0.17), Color(0.12, 0.07, 0.13),
			Color(0.08, 0.04, 0.08), Color(0.92, 0.78, 0.88)],
		# Act III — Dusk/Night
		11: [Color(0.04, 0.04, 0.08), Color(0.08, 0.09, 0.16),
			Color(0.17, 0.18, 0.26), Color(0.26, 0.26, 0.32),
			Color(0.11, 0.12, 0.19), Color(0.08, 0.09, 0.14),
			Color(0.05, 0.05, 0.09), Color(0.76, 0.84, 1.0)],
		12: [Color(0.04, 0.04, 0.08), Color(0.08, 0.08, 0.15),
			Color(0.16, 0.17, 0.25), Color(0.25, 0.25, 0.31),
			Color(0.10, 0.11, 0.18), Color(0.07, 0.08, 0.13),
			Color(0.04, 0.04, 0.08), Color(0.74, 0.82, 1.0)],
		13: [Color(0.03, 0.03, 0.07), Color(0.07, 0.07, 0.14),
			Color(0.15, 0.16, 0.24), Color(0.24, 0.24, 0.30),
			Color(0.09, 0.10, 0.17), Color(0.06, 0.07, 0.12),
			Color(0.04, 0.04, 0.07), Color(0.72, 0.80, 1.0)],
		14: [Color(0.03, 0.03, 0.07), Color(0.06, 0.07, 0.13),
			Color(0.14, 0.15, 0.23), Color(0.23, 0.23, 0.29),
			Color(0.09, 0.09, 0.16), Color(0.06, 0.06, 0.11),
			Color(0.03, 0.03, 0.07), Color(0.70, 0.78, 1.0)],
		15: [Color(0.05, 0.03, 0.06), Color(0.10, 0.06, 0.12),
			Color(0.20, 0.12, 0.18), Color(0.30, 0.20, 0.26),
			Color(0.12, 0.08, 0.14), Color(0.09, 0.06, 0.11),
			Color(0.05, 0.03, 0.06), Color(0.88, 0.76, 0.84)],
		# Act IV — Night/Storm
		16: [Color(0.03, 0.03, 0.07), Color(0.06, 0.06, 0.13),
			Color(0.14, 0.14, 0.22), Color(0.22, 0.22, 0.28),
			Color(0.08, 0.08, 0.15), Color(0.05, 0.05, 0.10),
			Color(0.03, 0.03, 0.06), Color(0.68, 0.76, 1.0)],
		17: [Color(0.03, 0.03, 0.06), Color(0.06, 0.06, 0.12),
			Color(0.13, 0.13, 0.21), Color(0.21, 0.21, 0.27),
			Color(0.08, 0.08, 0.14), Color(0.05, 0.05, 0.09),
			Color(0.03, 0.03, 0.06), Color(0.66, 0.74, 1.0)],
		18: [Color(0.03, 0.02, 0.06), Color(0.06, 0.05, 0.12),
			Color(0.13, 0.12, 0.20), Color(0.21, 0.20, 0.26),
			Color(0.08, 0.07, 0.14), Color(0.05, 0.04, 0.09),
			Color(0.03, 0.02, 0.06), Color(0.64, 0.72, 1.0)],
		19: [Color(0.03, 0.02, 0.06), Color(0.06, 0.05, 0.11),
			Color(0.12, 0.11, 0.19), Color(0.20, 0.19, 0.25),
			Color(0.07, 0.06, 0.13), Color(0.05, 0.04, 0.08),
			Color(0.03, 0.02, 0.05), Color(0.62, 0.70, 1.0)],
		20: [Color(0.06, 0.03, 0.06), Color(0.12, 0.06, 0.12),
			Color(0.22, 0.12, 0.20), Color(0.32, 0.20, 0.28),
			Color(0.14, 0.09, 0.15), Color(0.10, 0.06, 0.11),
			Color(0.06, 0.03, 0.06), Color(0.86, 0.74, 0.82)],
		# Act V — Storm/Dawn
		21: [Color(0.04, 0.03, 0.07), Color(0.08, 0.07, 0.14),
			Color(0.16, 0.15, 0.24), Color(0.25, 0.24, 0.30),
			Color(0.10, 0.09, 0.17), Color(0.07, 0.06, 0.12),
			Color(0.04, 0.03, 0.07), Color(0.78, 0.86, 1.0)],
		22: [Color(0.04, 0.03, 0.07), Color(0.07, 0.06, 0.13),
			Color(0.15, 0.14, 0.23), Color(0.24, 0.23, 0.29),
			Color(0.09, 0.08, 0.16), Color(0.06, 0.05, 0.11),
			Color(0.03, 0.03, 0.06), Color(0.76, 0.84, 1.0)],
		23: [Color(0.04, 0.03, 0.06), Color(0.07, 0.06, 0.12),
			Color(0.14, 0.13, 0.22), Color(0.23, 0.22, 0.28),
			Color(0.09, 0.08, 0.15), Color(0.06, 0.05, 0.10),
			Color(0.03, 0.03, 0.06), Color(0.74, 0.82, 1.0)],
		24: [Color(0.04, 0.03, 0.06), Color(0.07, 0.06, 0.12),
			Color(0.14, 0.13, 0.21), Color(0.22, 0.21, 0.27),
			Color(0.08, 0.07, 0.14), Color(0.06, 0.05, 0.10),
			Color(0.03, 0.03, 0.06), Color(0.72, 0.80, 1.0)],
		25: [Color(0.06, 0.03, 0.05), Color(0.12, 0.06, 0.10),
			Color(0.22, 0.12, 0.18), Color(0.34, 0.20, 0.26),
			Color(0.14, 0.08, 0.12), Color(0.10, 0.06, 0.09),
			Color(0.06, 0.03, 0.05), Color(0.90, 0.76, 0.86)],
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
