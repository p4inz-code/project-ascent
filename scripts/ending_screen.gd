class_name EndingScreen
extends CanvasLayer
## Shown when the last level is cleared. What it says depends on the cores
## (orbs) the player has banked:
##
##   100 or more   THE GATE OPENS: a ten-second cinematic, the true ending.
##   90 to 99      so close: the gate stays shut, and it says how many are missing.
##   anything less the gate needs 100: go back for more.
##
## It ends in three choices:  CONTINUE, HOME SCREEN, RESET PROGRESS (with a
## confirmation). CONTINUE moves on to the coming-soon card; the other two ask the
## game to act via signals, so this screen never touches game state by itself.
##
## The campaign is complete either way; Level Select always lets the player go back
## for cores.

signal closed
signal home_requested
signal reset_requested

enum Result { OPEN, CLOSE, SHUT }

const PX := 3.0
const GATE_SCALE := 12.0

## Cinematic timeline (seconds), for the OPEN ending.
const T_COUNT_END := 2.4
const T_GATE_OPEN := 2.8
const T_GATE_FULL := 4.6
const T_WALK := 4.6
const T_FLASH := 9.0
const T_LINES_END := 10.2
const T_OPTIONS := 11.0

var total: int = 0
var goal: int = 100
var result: Result = Result.SHUT
var skip_animation: bool = false   # tests set this to land on the final state at once

var _counter: Label
var _headline: Label
var _line: Label
var _gate_holder: Node2D
var _gate: GoalGate
var _rays: Control
var _flash: ColorRect
var _trevor: AnimatedSprite2D
var _trevor_holder: Control
var _choices: VBoxContainer
var _button: Button          # CONTINUE
var _home: Button
var _reset: Button
var _confirm: HBoxContainer
var _time: float = 0.0
var _opened: float = 0.0           # 0..1, how far the gate has swung open
var _shown: int = 0
var _options_shown: bool = false
var _lines_index: int = -1


static func result_for(cores: int, target: int) -> Result:
	if cores >= target:
		return Result.OPEN
	if cores >= target - 10:
		return Result.CLOSE
	return Result.SHUT


func headline_text() -> String:
	match result:
		Result.OPEN:
			return "THE GATE OPENS"
		Result.CLOSE:
			var missing := goal - total
			return "ONE CORE SHORT" if missing == 1 else "%d CORES SHORT" % missing
		_:
			return "THE GATE STAYS SHUT"


func pip_text() -> String:
	match result:
		Result.OPEN:
			return "THAT IS ONE HUNDRED. TREVOR... THE GATE IS OPEN. LET US GO HOME."
		Result.CLOSE:
			return "SO CLOSE. THE SPIRE IS STILL KEEPING A FEW. GO BACK FOR THEM."
		_:
			return "THE GATE NEEDS ONE HUNDRED CORES. THE SPIRE STILL HAS PLENTY. LEVEL SELECT WILL TAKE YOU BACK."


## The cinematic's spoken lines, with the time each begins (OPEN ending only).
func cinematic_lines() -> Array:
	return [
		[4.8, "ONE HUNDRED CORES. THE SPIRE HAS NOTHING LEFT TO KEEP."],
		[6.4, "THE GATE IS OPEN, TREVOR."],
		[8.0, "...LET US GO HOME."],
		[9.4, "YOU DID THE JUMPING. I DID... SOME OF THE NAVIGATING."],
	]


func is_cinematic() -> bool:
	return result == Result.OPEN


func options_visible() -> bool:
	return _options_shown


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 235
	result = result_for(total, goal)
	_build()
	if skip_animation:
		_time = T_OPTIONS + 1.0
		_shown = total
		_opened = 1.0 if result == Result.OPEN else 0.0
		_show_options()
		_refresh()


func _build() -> void:
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.08, 0.96)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	_rays = Control.new()
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	add_child(_rays)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var col := VBoxContainer.new()
	col.theme = UITheme.build()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(760, 0)
	centre.add_child(col)

	# The gate stage: the door art, with Trevor walking toward it in the cinematic.
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 26.0 * GATE_SCALE)
	col.add_child(stage)
	# The real gate from the levels, drawn large: sockets lit, field draining as it opens.
	_gate_holder = Node2D.new()
	_gate_holder.position = Vector2(380.0, 26.0 * GATE_SCALE * 0.5 + 6.0)
	_gate_holder.scale = Vector2(2.6, 2.6)
	stage.add_child(_gate_holder)
	_gate = GoalGate.new()
	_gate.door_size = Vector2(56.0, 96.0)
	_gate.is_final = true
	_gate.core_goal = goal
	_gate.cores = total
	_gate_holder.add_child(_gate)
	_trevor_holder = Control.new()
	_trevor_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trevor_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_trevor_holder)
	var gs := get_node_or_null("/root/GameSettings")
	var frames := PlayerVisuals.build_frames(gs.sheet_path() if gs != null and gs.has_method("sheet_path")
		else "res://assets/pixel/player_sheet.png")
	if frames != null:
		_trevor = AnimatedSprite2D.new()
		_trevor.sprite_frames = frames
		_trevor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_trevor.scale = Vector2(PX * 3.0, PX * 3.0)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/palette_swap.gdshader")
		mat.set_shader_parameter("suit", gs.get_player_color() if gs != null else Color(0.42, 0.78, 1.0))
		PlayerVisuals.apply_look(mat, gs)
		_trevor.material = mat
		_trevor.visible = false
		_trevor.play("run")
		_trevor_holder.add_child(_trevor)

	_counter = Label.new()
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.add_theme_font_size_override("font_size", UITheme.sz(40))
	col.add_child(_counter)
	_headline = Label.new()
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE)
	_headline.text = headline_text()
	_headline.modulate.a = 0.0
	col.add_child(_headline)
	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_color_override("font_color", UITheme.AMBER)
	_line.text = "" if is_cinematic() else pip_text()
	_line.modulate.a = 0.0
	col.add_child(_line)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	_choices.visible = false
	col.add_child(_choices)
	_button = _choice_button("CONTINUE", close)
	_home = _choice_button("HOME SCREEN", _on_home)
	_reset = _choice_button("RESET PROGRESS", _on_reset)
	_reset.add_theme_color_override("font_color", UITheme.DANGER)
	_confirm = HBoxContainer.new()
	_confirm.add_theme_constant_override("separation", 8)
	_confirm.visible = false
	var warn := Label.new()
	warn.text = "ERASE ALL PROGRESS?"
	warn.add_theme_color_override("font_color", UITheme.DANGER)
	warn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.add_child(warn)
	var yes := Button.new()
	yes.text = "YES, ERASE"
	yes.name = "ConfirmYes"
	yes.add_theme_color_override("font_color", UITheme.DANGER)
	yes.pressed.connect(_on_reset_confirmed)
	_confirm.add_child(yes)
	var no := Button.new()
	no.text = "NO"
	no.name = "ConfirmNo"
	no.pressed.connect(_on_reset_cancelled)
	_confirm.add_child(no)
	_choices.add_child(_confirm)

	# Whole-screen flash for the moment the gate lets him through.
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.95, 0.8, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_refresh()


func _choice_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(handler)
	_choices.add_child(b)
	return b


func _show_options() -> void:
	_options_shown = true
	_choices.visible = true
	_confirm.visible = false
	_button.visible = true
	_home.visible = true
	_reset.visible = true
	_button.grab_focus()


func _on_home() -> void:
	home_requested.emit()
	queue_free()


func _on_reset() -> void:
	# Never in one press: erasing progress needs a second, explicit yes.
	_button.visible = false
	_home.visible = false
	_reset.visible = false
	_confirm.visible = true
	_confirm.get_node("ConfirmNo").grab_focus()


func _on_reset_cancelled() -> void:
	_show_options()


func _on_reset_confirmed() -> void:
	reset_requested.emit()
	queue_free()


func _draw_rays() -> void:
	if _opened <= 0.0:
		return
	var vp := _rays.size
	var c := Vector2(vp.x * 0.5, vp.y * 0.5 - 60.0)
	var length := maxf(vp.x, vp.y) * 0.9 * _opened
	for i in 15:
		var ang := -PI * 0.5 + (float(i) - 7.0) * 0.13
		var a := 0.30 * _opened * (1.0 - absf(float(i) - 7.0) / 9.0)
		_rays.draw_line(c, c + Vector2(cos(ang), sin(ang)) * length, Color(1.0, 0.85, 0.45, a), 26.0)


func _refresh() -> void:
	if _counter == null:
		return
	_counter.text = "%d / %d CORES" % [_shown, goal]
	var full := _shown >= goal
	_counter.add_theme_color_override("font_color", UITheme.AMBER if full else UITheme.TEXT)
	_headline.add_theme_color_override("font_color",
		UITheme.AMBER if result == Result.OPEN else (UITheme.DANGER if result == Result.SHUT else UITheme.accent))
	# The gate drains open and brightens.
	if _gate != null:
		_gate._open = _opened
		_gate.cores = _shown if not skip_animation else total
		_gate.modulate = Color(1, 1, 1).lerp(Color(1.5, 1.35, 0.95), _opened)
	_rays.queue_redraw()


func _process(delta: float) -> void:
	if skip_animation:
		return
	_time += delta
	if is_cinematic():
		_step_cinematic()
	else:
		_step_simple()
	_refresh()


func _step_simple() -> void:
	var count_t := clampf(_time / 2.0, 0.0, 1.0)
	_shown = int(round(float(total) * count_t))
	if _time > 2.2:
		_headline.modulate.a = clampf((_time - 2.2) / 0.6, 0.0, 1.0)
	if _time > 3.2:
		_line.modulate.a = clampf((_time - 3.2) / 0.6, 0.0, 1.0)
	if _time > 4.4 and not _options_shown:
		_show_options()


## The ten-second ending: the count fills, the gate opens, Trevor walks into the
## light with PIP's lines, a flash, then the three choices.
func _step_cinematic() -> void:
	_shown = int(round(float(total) * clampf(_time / T_COUNT_END, 0.0, 1.0)))
	_opened = clampf((_time - T_GATE_OPEN) / (T_GATE_FULL - T_GATE_OPEN), 0.0, 1.0)
	if _time > T_COUNT_END:
		_headline.modulate.a = clampf((_time - T_COUNT_END) / 0.6, 0.0, 1.0)

	# Trevor enters from the left and walks to the door, shrinking into the light.
	if _trevor != null:
		var walking := _time >= T_WALK and _time < T_FLASH
		_trevor.visible = walking
		if walking:
			var k := clampf((_time - T_WALK) / (T_FLASH - T_WALK), 0.0, 1.0)
			var door_x := 380.0
			var start_x := 40.0
			var feet_y := 26.0 * GATE_SCALE * 0.5 + 6.0 + 96.0 * 0.5 * 2.6
			_trevor.position = Vector2(lerpf(start_x, door_x, k), feet_y - 10.0 * _trevor.scale.y)
			var fade := 1.0 - clampf((k - 0.85) / 0.15, 0.0, 1.0)
			_trevor.modulate.a = fade

	# PIP's lines, one at a time.
	var idx := -1
	var lines := cinematic_lines()
	for i in lines.size():
		if _time >= float(lines[i][0]):
			idx = i
	if idx != _lines_index:
		_lines_index = idx
		_line.text = String(lines[idx][1]) if idx >= 0 else ""
	if idx >= 0:
		var start: float = float(lines[idx][0])
		_line.modulate.a = clampf((_time - start) / 0.4, 0.0, 1.0)
	if _time > T_LINES_END:
		_line.modulate.a = clampf(1.0 - (_time - T_LINES_END) / 0.6, 0.0, 1.0)

	# The flash as he steps through.
	if _time >= T_FLASH - 0.4:
		var f := clampf((_time - (T_FLASH - 0.4)) / 0.4, 0.0, 1.0)
		var out := clampf((_time - T_FLASH - 0.2) / 1.4, 0.0, 1.0)
		_flash.color.a = f * (1.0 - out) * 0.9
	if _time >= T_OPTIONS and not _options_shown:
		_show_options()


func _input(event: InputEvent) -> void:
	# Any key or click finishes the animation; then the choices are there to pick.
	if not _options_shown and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_time = maxf(_time, T_OPTIONS if is_cinematic() else 4.5)
		if is_cinematic():
			_opened = 1.0
			_shown = total
			_headline.modulate.a = 1.0
			_flash.color.a = 0.0
			if _trevor != null:
				_trevor.visible = false
			_line.text = ""
		_show_options()
		get_viewport().set_input_as_handled()
	elif _options_shown and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _confirm.visible:
			_on_reset_cancelled()
		else:
			close()


func close() -> void:
	closed.emit()
	queue_free()
