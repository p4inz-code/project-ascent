class_name TutorialGuide
extends CanvasLayer
## PIP teaches the verbs, one at a time, in the tutorial level. Each lesson has a zone
## along the course, a line of instruction (with the player's own key names, so a
## rebinding is respected), and an event that completes it: the player actually doing
## the thing. Nothing here can block the way; the level is open from end to end, and a
## missed lesson simply stays on screen until it is done.
##
## Lessons: run, jump, higher jump (hold), dash, slide, wall-jump.

signal lesson_done(index: int)
signal finished

enum Event { RUN, JUMP, HIGH_JUMP, DASH, SLIDE, WALL_JUMP }

## [x_from, x_to, event, line template]. {key:action} is replaced by the bound key.
const LESSONS := [
	[0.0, 1100.0, Event.RUN, "PRESS {move_left} / {move_right} TO RUN."],
	[1100.0, 2060.0, Event.JUMP, "A GAP. PRESS {jump} TO JUMP."],
	[2060.0, 2560.0, Event.HIGH_JUMP, "HIGHER. HOLD {jump} LONGER FOR A BIGGER JUMP."],
	[2560.0, 3160.0, Event.DASH, "TOO FAR TO JUMP. JUMP, THEN PRESS {dash} TO DASH ACROSS."],
	[3160.0, 4150.0, Event.SLIDE, "RUN FIRST, THEN PRESS {slide} TO SLIDE."],
	[4150.0, 99999.0, Event.WALL_JUMP, "JUMP INTO A WALL, THEN PRESS {jump} AGAIN TO KICK OFF."],
]
const PRAISE := ["NICE.", "THAT IS IT.", "CLEAN.", "GOOD.", "THERE YOU GO.", "ON TO THE NEXT."]
const RUN_DISTANCE := 260.0
const HIGH_JUMP_RISE := 60.0     # standing this much above where the lesson began

var index: int = 0
var done: Array[bool] = []
var player: Player = null

var _box: PanelContainer
var _line: Label
var _speaker: Label
var _flash: float = 0.0
var _praise: String = ""
var _start_x: float = 0.0
var _zone_floor_y: float = 0.0
var _jumped_in_zone: bool = false
var _all_done: bool = false
var _primed: bool = false      # the lesson baseline is taken once the player has been placed


func _ready() -> void:
	layer = 102
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _l in LESSONS:
		done.append(false)
	_build()
	_refresh()


func attach(p: Player) -> void:
	player = p
	p.jumped.connect(func(): _on_event(Event.JUMP))
	p.dashed.connect(func(): _on_event(Event.DASH))
	p.slid.connect(func(): _on_event(Event.SLIDE))
	p.wall_jumped.connect(func(): _on_event(Event.WALL_JUMP))


func _build() -> void:
	_box = PanelContainer.new()
	_box.theme = UITheme.build()
	_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_box.offset_left = -430.0
	_box.offset_right = 430.0
	_box.offset_top = -176.0
	_box.offset_bottom = -76.0
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	_box.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	m.add_child(col)
	_speaker = Label.new()
	_speaker.text = "PIP"
	_speaker.add_theme_color_override("font_color", UITheme.AMBER)
	_speaker.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	col.add_child(_speaker)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 22)
	col.add_child(_line)


## "PRESS A / D TO RUN" from a template, using the player's real bindings.
static func render(template: String) -> String:
	var out := template
	for action in InputBindings.ACTIONS:
		var token := "{%s}" % action
		if out.contains(token):
			var keys := InputBindings.keys_for(action)
			out = out.replace(token, InputBindings.key_name(keys[0]) if not keys.is_empty() else "?")
	return out


## The lesson the player is in, by x position (-1 when none).
func lesson_at(x: float) -> int:
	for i in LESSONS.size():
		if x >= float(LESSONS[i][0]) and x < float(LESSONS[i][1]):
			return i
	return -1


func current_text() -> String:
	if _all_done:
		return "THAT IS EVERYTHING. THE DOOR IS AHEAD. I WILL BE WITH YOU THE WHOLE WAY."
	if _flash > 0.0:
		return _praise
	var i := index
	return render(String(LESSONS[i][3])) if i >= 0 and i < LESSONS.size() else ""


func _refresh() -> void:
	if _line != null:
		_line.text = current_text()


func _on_event(event: int) -> void:
	if _all_done or index >= LESSONS.size():
		return
	var want: int = int(LESSONS[index][2])
	if event == Event.JUMP:
		_jumped_in_zone = true
	if event == want and want != Event.RUN and want != Event.HIGH_JUMP:
		_complete(index)


func _complete(i: int) -> void:
	if i != index or done[i]:
		return
	done[i] = true
	_praise = PRAISE[i % PRAISE.size()]
	_flash = 1.1
	lesson_done.emit(i)
	index += 1
	_jumped_in_zone = false
	if index >= LESSONS.size():
		_all_done = true
		finished.emit()
	else:
		_start_x = player.global_position.x if player != null else 0.0
		_zone_floor_y = player.global_position.y if player != null else 0.0
	_refresh()


func _process(delta: float) -> void:
	if player == null:
		return
	_flash = maxf(_flash - delta, 0.0)
	if not _primed:
		_primed = true
		_start_x = player.global_position.x
		_zone_floor_y = player.global_position.y
	if index < LESSONS.size() and not _all_done:
		var want: int = int(LESSONS[index][2])
		# Lessons that are measured rather than signalled.
		if want == Event.RUN and absf(player.global_position.x - _start_x) >= RUN_DISTANCE:
			_complete(index)
		elif want == Event.HIGH_JUMP and player.is_on_floor() \
				and _zone_floor_y - player.global_position.y >= HIGH_JUMP_RISE:
			_complete(index)
		# Walking into a later zone brings that lesson up, even if an earlier one was skipped.
		var here := lesson_at(player.global_position.x)
		if here > index:
			while index < here:
				done[index] = true
				index += 1
			_start_x = player.global_position.x
			_zone_floor_y = player.global_position.y
	_refresh()
