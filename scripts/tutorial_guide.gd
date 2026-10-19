class_name TutorialGuide
extends CanvasLayer
## PIP teaches the verbs in five sets, one lesson at a time. Each lesson has a zone along
## the course, a line of instruction (written with the player's own keys, or the button
## names of the pad in their hands), and an event that completes it: the player actually
## doing the thing. Nothing here can block the way; the course is open from end to end, and
## a missed lesson simply stays on screen until it is done or the player walks on.
##
## The course teaches by situation first: every lesson is a real gap, step, wall or flag the
## verb is needed for. The words only point at it.
##
## Sets: 1 MOVE, 2 JUMP, 3 DASH & SLIDE, 4 WALLS, 5 THE WORLD.

signal lesson_done(index: int)
signal set_started(set_index: int)
signal finished

enum Event { RUN, TURN, JUMP, HIGH_JUMP, DASH, SLIDE, WALL_SLIDE, WALL_JUMP, CHECKPOINT, KEYS }

const SET_NAMES: Array[String] = ["MOVE", "JUMP", "DASH AND SLIDE", "WALLS", "THE WORLD"]

## Each lesson: set (0-based), the x range it covers, the events that complete it, and the
## line. {action} is replaced by the bound key / pad button.
const LESSONS: Array = [
	{"set": 0, "from": 0.0, "to": 600.0, "events": [Event.RUN],
		"text": "PRESS {move_left} / {move_right} TO RUN."},
	{"set": 0, "from": 600.0, "to": 1100.0, "events": [Event.TURN],
		"text": "TURN AROUND. PRESS {move_left} TO RUN BACK."},
	{"set": 1, "from": 1100.0, "to": 2060.0, "events": [Event.JUMP],
		"text": "A GAP. PRESS {jump} TO JUMP."},
	{"set": 1, "from": 2060.0, "to": 2560.0, "events": [Event.HIGH_JUMP],
		"text": "HIGHER. HOLD {jump} LONGER FOR A BIGGER JUMP."},
	{"set": 2, "from": 2560.0, "to": 3160.0, "events": [Event.DASH],
		"text": "TOO FAR TO JUMP. JUMP, THEN PRESS {dash} TO DASH ACROSS."},
	{"set": 2, "from": 3160.0, "to": 4150.0, "events": [Event.SLIDE],
		"text": "RUN FIRST, THEN PRESS {slide} TO SLIDE."},
	{"set": 3, "from": 4150.0, "to": 4380.0, "events": [Event.WALL_SLIDE, Event.WALL_JUMP],
		"text": "JUMP INTO THE WALL AND HOLD TOWARD IT. YOU SLIDE DOWN SLOWLY."},
	{"set": 3, "from": 4380.0, "to": 4700.0, "events": [Event.WALL_JUMP],
		"text": "PRESS {jump} ON THE WALL TO KICK OFF. CLIMB THE SHAFT WALL TO WALL."},
	{"set": 4, "from": 4700.0, "to": 5330.0, "events": [Event.KEYS],
		"text": "PRESS {toggle_help} FOR ALL CONTROLS. {pause} PAUSES, {restart} RESTARTS."},
	{"set": 4, "from": 5330.0, "to": 99999.0, "events": [Event.CHECKPOINT],
		"text": "TOUCH THE FLAG. IF YOU FALL, YOU COME BACK TO IT."},
]
const PRAISE := ["NICE.", "THAT IS IT.", "CLEAN.", "GOOD.", "THERE YOU GO.", "ON TO THE NEXT."]
const RUN_DISTANCE := 260.0
const TURN_DISTANCE := 110.0
const HIGH_JUMP_RISE := 60.0     # standing this much above where the lesson began
const SET_CARD_TIME := 2.4

var index: int = 0
var done: Array[bool] = []
var player: Player = null

var _box: PanelContainer
var _line: Label
var _speaker: Label
var _flash: float = 0.0
var _praise: String = ""
var _start_x: float = 0.0
var _max_x: float = 0.0
var _zone_floor_y: float = 0.0
var _all_done: bool = false
var _primed: bool = false      # the lesson baseline is taken once the player has been placed
var _card_timer: float = 0.0
var _current_set: int = -1


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
	p.wall_slide_started.connect(func(): _on_event(Event.WALL_SLIDE))


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
	_speaker.add_theme_color_override("font_color", UITheme.AMBER)
	_speaker.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	col.add_child(_speaker)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", UITheme.sz(22))
	col.add_child(_line)


## "PRESS A / D TO RUN" from a template, using what the player is actually using: their own
## (possibly rebound) keys, or the button names of the gamepad in their hands.
static func render(template: String) -> String:
	var out := template
	var device: Node = null
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		device = (loop as SceneTree).root.get_node_or_null("InputDevice")
	var actions: Array = InputBindings.ACTIONS.duplicate()
	actions.append("pause")
	for action in actions:
		var token := "{%s}" % action
		if not out.contains(token):
			continue
		if device != null:
			out = out.replace(token, String(device.prompt(action)))
		else:
			var keys := InputBindings.keys_for(action)
			out = out.replace(token, InputBindings.key_name(keys[0]) if not keys.is_empty() else "?")
	return out


## The lesson the player is in, by x position (-1 when none).
func lesson_at(x: float) -> int:
	for i in LESSONS.size():
		if x >= float(LESSONS[i]["from"]) and x < float(LESSONS[i]["to"]):
			return i
	return -1


static func set_of(lesson: int) -> int:
	return int(LESSONS[lesson]["set"]) if lesson >= 0 and lesson < LESSONS.size() else -1


func current_text() -> String:
	if _all_done:
		return "THAT IS EVERYTHING. THE DOOR IS AHEAD. I WILL BE WITH YOU THE WHOLE WAY."
	if _flash > 0.0:
		return _praise
	return render(String(LESSONS[index]["text"])) if index >= 0 and index < LESSONS.size() else ""


## "PIP  2/5  JUMP": which set the player is in.
func speaker_text() -> String:
	if _all_done:
		return "PIP"
	var s := set_of(index)
	return "PIP   %d/%d   %s" % [s + 1, SET_NAMES.size(), SET_NAMES[s]] if s >= 0 else "PIP"


func _refresh() -> void:
	if _line != null:
		_line.text = current_text()
	if _speaker != null:
		_speaker.text = speaker_text()


func _on_event(event: int) -> void:
	if _all_done or index >= LESSONS.size():
		return
	if event in (LESSONS[index]["events"] as Array) and not _measured(index):
		_complete(index)


## Lessons that are measured every frame rather than signalled.
func _measured(i: int) -> bool:
	var ev: Array = LESSONS[i]["events"]
	return Event.RUN in ev or Event.TURN in ev or Event.HIGH_JUMP in ev \
		or Event.CHECKPOINT in ev or Event.KEYS in ev


func _complete(i: int) -> void:
	if i != index or done[i]:
		return
	done[i] = true
	_praise = PRAISE[i % PRAISE.size()]
	_flash = 1.1
	lesson_done.emit(i)
	index += 1
	if index >= LESSONS.size():
		_all_done = true
		finished.emit()
	else:
		_rebase()
	_refresh()


func _rebase() -> void:
	if player != null:
		_start_x = player.global_position.x
		_max_x = _start_x
		_zone_floor_y = player.global_position.y


## Raise the set card when the player enters a new set.
func _announce_set() -> void:
	var s := set_of(index)
	if s != _current_set and s >= 0:
		_current_set = s
		_card_timer = SET_CARD_TIME
		set_started.emit(s)


func _checkpoint_taken() -> bool:
	var level := get_parent()
	return level != null and bool(level.get("_has_checkpoint"))


func _process(delta: float) -> void:
	if player == null:
		return
	_flash = maxf(_flash - delta, 0.0)
	_card_timer = maxf(_card_timer - delta, 0.0)
	if not _primed:
		_primed = true
		_rebase()
	if index < LESSONS.size() and not _all_done:
		var ev: Array = LESSONS[index]["events"]
		var x := player.global_position.x
		_max_x = maxf(_max_x, x)
		if Event.RUN in ev and absf(x - _start_x) >= RUN_DISTANCE:
			_complete(index)
		elif Event.TURN in ev and _max_x - x >= TURN_DISTANCE:
			_complete(index)
		elif Event.HIGH_JUMP in ev and player.is_on_floor() \
				and _zone_floor_y - player.global_position.y >= HIGH_JUMP_RISE:
			_complete(index)
		elif Event.KEYS in ev and Input.is_action_just_pressed("toggle_help"):
			_complete(index)
		elif Event.CHECKPOINT in ev and _checkpoint_taken():
			_complete(index)
		# Walking into a later zone brings that lesson up, even if an earlier one was skipped.
		var here := lesson_at(x)
		if here > index:
			while index < here:
				done[index] = true
				index += 1
			_rebase()
	_announce_set()
	_refresh()
	# The set card replaces the speaker line for a moment when a set begins.
	if _card_timer > 0.0 and _speaker != null and not _all_done:
		_speaker.text = "SET %d OF %d:  %s" % [set_of(index) + 1, SET_NAMES.size(), SET_NAMES[set_of(index)]]
