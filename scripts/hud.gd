class_name Hud
extends CanvasLayer
## On-screen HUD: the controls panel, the run clock, the attempt counter,
## the level indicator, and the level-complete banner.
##
## The controls panel is generated from the live `InputMap` rather than from a
## hand-written list of key names. That is the whole point of building it this
## way: a printed control list is the first thing to rot the moment a binding
## changes, and a platformer that lies about its own controls is worse than one
## that shows none. `tools/setup_input.gd` owns the bindings; this reads them.

## Seconds the panel stays up on a fresh start before fading out on its own.
@export var auto_hide_delay: float = 8.0
## Fade duration for the panel and the completion banner.
@export var fade_time: float = 0.35
## How long the "LEVEL COMPLETE" banner stays on screen.
@export var banner_time: float = 2.4

## Rows of the controls panel, in display order. Several actions can share a row
## (Move is two), in which case their primary keys are joined with " / ".
const ROWS: Array = [
	{"label": "Move", "actions": ["move_left", "move_right"]},
	{"label": "Jump", "actions": ["jump"]},
	{"label": "Dash", "actions": ["dash"]},
	{"label": "Restart", "actions": ["restart"]},
	{"label": "Controls", "actions": ["toggle_help"]},
]

## Readable names for the gamepad buttons the game binds. Godot exposes the enum
## but not a display string, and "JOY_BUTTON_A" is not something to show a player.
const PAD_BUTTONS: Dictionary = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
}

## Arrow keys read far better as glyphs than as the words Godot returns.
const KEY_GLYPHS: Dictionary = {
	"Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
}

@onready var _panel: Control = $Controls
@onready var _grid: GridContainer = $Controls/Margin/Rows/Grid
@onready var _hint: Label = $Hint
@onready var _clock: Label = $Stats/Clock
@onready var _attempts: Label = $Stats/Attempts
@onready var _banner: Control = $Banner
@onready var _banner_title: Label = $Banner/Box/Title
@onready var _banner_time: Label = $Banner/Box/Time

## Level indicator (created dynamically since the .tscn doesn't have it yet)
var _level_label: Label = null

var _level: Node = null
var _hide_countdown: float = 0.0
var _tween: Tween = null
var _banner_tween: Tween = null


func _ready() -> void:
	_build_rows()
	_banner.modulate.a = 0.0
	_banner.visible = false
	_hint.modulate.a = 0.0
	_panel.modulate.a = 1.0
	_panel.visible = true
	_hide_countdown = auto_hide_delay

	_level = get_parent()
	# Navigate up to find the level node if we're inside game_scene
	if _level != null and _level.name == "LevelContainer":
		_level = _level.get_parent().get_node_or_null("LevelContainer").get_child(0)
	if _level == null:
		_level = get_parent()
	if _level != null and _level.has_signal("level_completed"):
		_level.level_completed.connect(_on_level_completed)

	# Create level indicator label
	_create_level_label()
	_refresh_stats()


func _create_level_label() -> void:
	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(0.56, 0.68, 0.84, 0.7))
	_level_label.position = Vector2(34, 30)
	# Check if parent is CanvasLayer (which it is)
	if self is CanvasLayer:
		add_child(_level_label)
	_update_level_label()


func _update_level_label() -> void:
	if _level_label == null:
		return
	var level_num = 1
	if _level != null and _level.has_method("get") and _level.get("level_number") != null:
		level_num = _level.level_number
	var level_def = LevelData.get_level(level_num)
	_level_label.text = "LEVEL %d — %s" % [level_num, level_def.name]


## Fill the controls grid from the live InputMap. Called once; the bindings do
## not change at runtime.
func _build_rows() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for row in ROWS:
		var actions: Array = row["actions"]
		_add_cell(String(row["label"]), 0.62, false)
		_add_cell(_keys_for(actions, 0), 1.0, true)
		_add_cell(_keys_for(actions, 1), 0.45, true)
		_add_cell(_pad_for(actions), 0.45, true)


func _add_cell(text: String, alpha: float, mono: bool) -> void:
	var label := Label.new()
	label.text = text
	label.modulate.a = alpha
	label.add_theme_font_size_override("font_size", 17 if mono else 16)
	if mono:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(label)


## The `variant`-th keyboard key bound to each action, joined with " / ".
## Variant 0 is the primary binding (A / D), variant 1 the alternate (← / →), so
## the panel shows both without turning into a run-on list.
func _keys_for(actions: Array, variant: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for action in actions:
		var keys := _keyboard_keys(String(action))
		if variant < keys.size():
			parts.append(keys[variant])
	return " / ".join(parts)


func _keyboard_keys(action: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not InputMap.has_action(action):
		return out
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var key_name := OS.get_keycode_string(key.physical_keycode)
		out.append(String(KEY_GLYPHS.get(key_name, key_name)))
	return out


## Gamepad bindings for a row: button names, or "Stick" when the action is bound
## to a joystick axis (both halves of Move collapse to one label).
func _pad_for(actions: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for action in actions:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			var button := event as InputEventJoypadButton
			if button != null:
				parts.append(String(PAD_BUTTONS.get(button.button_index, "Pad")))
				continue
			if event is InputEventJoypadMotion and not parts.has("Stick"):
				parts.append("Stick")
	return " / ".join(parts)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_help"):
		_set_panel_shown(not _panel_shown())
	elif _hide_countdown > 0.0:
		_hide_countdown -= delta
		if _hide_countdown <= 0.0:
			_set_panel_shown(false)
	_refresh_stats()


func _panel_shown() -> bool:
	return _panel.visible and _panel.modulate.a > 0.5


func _set_panel_shown(shown: bool) -> void:
	_hide_countdown = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_panel.visible = true
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "modulate:a", 1.0 if shown else 0.0, fade_time)
	_tween.tween_property(_hint, "modulate:a", 0.0 if shown else 1.0, fade_time)
	if not shown:
		_tween.chain().tween_callback(func() -> void: _panel.visible = false)


func _refresh_stats() -> void:
	if _level == null:
		return
	var shown: Variant = _level.get("last_run_time") if _banner.visible \
		else _level.get("run_time")
	_clock.text = format_time(shown)
	_attempts.text = "ATTEMPT %d" % int(_level.get("attempts"))
	_update_level_label()


## m:ss.cc — centiseconds matter in a precision platformer, hours do not.
static func format_time(seconds: Variant) -> String:
	var t := float(seconds) if seconds != null else 0.0
	var minutes := int(t) / 60
	var secs := int(t) % 60
	var cents := int(fmod(t, 1.0) * 100.0)
	return "%d:%02d.%02d" % [minutes, secs, cents]


func _on_level_completed() -> void:
	var level_num := 1
	if _level != null and _level.has_method("get") and _level.get("level_number") != null:
		level_num = _level.level_number
	_banner_title.text = "LEVEL %d COMPLETE" % level_num
	_banner_time.text = format_time(_level.get("last_run_time"))
	_banner.visible = true
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, fade_time)
	_banner_tween.tween_interval(banner_time)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, fade_time)
	_banner_tween.tween_callback(func() -> void: _banner.visible = false)
