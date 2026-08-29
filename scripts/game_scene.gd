extends Node2D
## Main game scene that manages level loading, transitions, pause overlay,
## and the overall game flow.
##
## This replaces main_scene.tscn as the entry point. It loads the current
## level as a child and overlays the pause menu.

var _current_level_scene: Node2D = null
var _pause_menu: CanvasLayer = null
var _level_container: Node2D
var _transition_overlay: ColorRect
var _transition_label: Label
var _transitioning: bool = false


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

	# Connect level completion
	if _current_level_scene.has_signal("level_completed"):
		_current_level_scene.level_completed.connect(_on_level_completed)


func _find_audio():
	if _current_level_scene != null and is_instance_valid(_current_level_scene):
		return _current_level_scene.get_node_or_null("Audio")
	return null


func _on_level_changed(level_number: int) -> void:
	# Show transition
	_transitioning = true
	var level_def = LevelData.get_level(level_number)
	_transition_label.text = "LEVEL %d\n%s" % [level_number, level_def.name]
	_transition_label.visible = true
	_transition_label.modulate.a = 1.0

	# Fade in overlay
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 1.0, 0.3)
	tween.tween_callback(_do_level_swap)
	tween.tween_interval(1.2)
	tween.tween_property(_transition_overlay, "color:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		_transition_label.visible = false
		_transitioning = false
	)


func _do_level_swap() -> void:
	_load_current_level()


func _on_level_completed() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.complete_current_level()


func _on_game_over() -> void:
	# Could show a game-over screen; for now restart from checkpoint
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.restart_from_checkpoint()
