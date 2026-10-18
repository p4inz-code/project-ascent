class_name Cutscene
extends CanvasLayer
## The opening story, told in four short beats: the rocket, the rift, the
## stranded arrival, and the door that costs orbs. About twenty seconds, always
## skippable, and shown once per save (replayable from the title menu).
##
## Built in code from the generated pixel sprites (tools/gen_pixel_art.py), the
## same way the rest of the UI is, so there is no scene file to drift out of
## step. It runs while the SceneTree is paused (the title menu pauses it), so
## the layer and every tween are pause-immune.
##
## docs/STORY_AND_ORBS.md says the story is "kept deliberately thin"; the beats
## below are that story and nothing more. It answers "why am I climbing" and
## "why am I collecting these", then gets out of the way.

signal finished

## World-unit-per-art-pixel for the story sprites. Whole numbers only: a
## fractional scale would smear the pixels.
const SPRITE_SCALE: float = 8.0
const BEATS: Array[String] = [
	"Trevor was aboard a rocket.",
	"Something went wrong.",
	"He came out the other side. Somewhere that isn't a place.",
	"Doors need orbs. He needs one hundred.",
]

var _bg: ColorRect
var _stage: Control
var _caption: Label
var _hint: Label
var _skipped: bool = false
var _tween: Tween


func _ready() -> void:
	layer = 230
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_play()


func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.03, 0.08)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_scatter_stars()

	var panel := PanelContainer.new()
	panel.theme = UITheme.build()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -170.0
	panel.offset_bottom = -60.0
	panel.custom_minimum_size = Vector2(1100, 110)
	_stage.add_child(panel)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.visible_characters = 0
	panel.add_child(_caption)

	_hint = Label.new()
	_hint.text = "ENTER - SKIP"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.modulate = Color(1, 1, 1, 0.5)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_right = -28.0
	_hint.offset_bottom = -22.0
	_stage.add_child(_hint)


## Fixed seed so the star field is the same every time it plays.
func _scatter_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 90:
		var star := ColorRect.new()
		var s := 3.0 if rng.randf() > 0.2 else 6.0
		star.size = Vector2(s, s)
		star.position = Vector2(rng.randf() * 1920.0, rng.randf() * 760.0)
		star.color = Color(0.8, 0.88, 1.0, rng.randf_range(0.25, 0.9))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(star)


func _sprite(path: String, pos: Vector2, scale_mult: float = 1.0) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(path) as Texture2D
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tr.texture != null:
		tr.custom_minimum_size = tr.texture.get_size() * SPRITE_SCALE * scale_mult
		tr.size = tr.custom_minimum_size
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.position = pos
	_stage.add_child(tr)
	return tr


func _say(index: int) -> void:
	_caption.text = BEATS[index]
	_caption.visible_characters = 0
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_caption, "visible_characters", BEATS[index].length(), 0.04 * BEATS[index].length())


func _play() -> void:
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# Beat 1 - the rocket crosses a calm sky.
	var rocket := _sprite("res://assets/pixel/rocket.png", Vector2(-260, 560))
	rocket.rotation = deg_to_rad(52)
	_tween.tween_callback(_say.bind(0))
	_tween.tween_property(rocket, "position", Vector2(930, 250), 4.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(rocket, "rotation", deg_to_rad(8), 4.2)
	_tween.tween_interval(0.8)

	# Beat 2 - it glitches, flashes, and is gone.
	_tween.tween_callback(_say.bind(1))
	for i in 6:
		_tween.tween_property(rocket, "position:x", 930.0 + (14.0 if i % 2 == 0 else -14.0), 0.07)
	_tween.tween_property(_bg, "color", Color(0.9, 0.9, 1.0), 0.12)
	_tween.tween_callback(func(): rocket.visible = false)
	_tween.tween_property(_bg, "color", Color(0.16, 0.06, 0.32), 0.9)
	_tween.tween_interval(0.9)

	# Beat 3 - the rift opens and Trevor tumbles out of it.
	_tween.tween_callback(_say.bind(2))
	var rift := _sprite("res://assets/pixel/rift.png", Vector2(960.0 - 24.0 * SPRITE_SCALE, 80))
	rift.pivot_offset = rift.size * 0.5
	rift.scale = Vector2(0.05, 0.05)
	rift.modulate.a = 0.0
	_tween.tween_property(rift, "modulate:a", 1.0, 0.4)
	_tween.parallel().tween_property(rift, "scale", Vector2.ONE, 1.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var trevor := _trevor()
	trevor.position = Vector2(930, 160)
	trevor.modulate.a = 0.0
	_tween.tween_property(trevor, "modulate:a", 1.0, 0.2)
	_tween.tween_property(trevor, "position:y", 560.0, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(trevor, "rotation", TAU * 2.0, 1.2)
	_tween.tween_property(trevor, "rotation", 0.0, 0.01)
	_tween.tween_interval(2.4)

	# Beat 4 - the door, and what it costs.
	_tween.tween_callback(_say.bind(3))
	_tween.tween_property(rift, "modulate:a", 0.0, 0.8)
	var door := _sprite("res://assets/pixel/door.png", Vector2(1380, 380))
	door.modulate.a = 0.0
	_tween.parallel().tween_property(door, "modulate:a", 1.0, 1.0)
	var orb := _sprite("res://assets/pixel/orb.png", Vector2(1120, 300), 1.5)
	var count := Label.new()
	count.text = "0 / 100"
	count.add_theme_font_size_override("font_size", 40)
	count.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	count.position = Vector2(1210, 296)
	_stage.add_child(count)
	orb.modulate.a = 0.0
	count.modulate.a = 0.0
	_tween.tween_property(orb, "modulate:a", 1.0, 0.6)
	_tween.parallel().tween_property(count, "modulate:a", 1.0, 0.6)
	_tween.tween_interval(3.6)

	_tween.tween_property(_bg, "color", Color(0, 0, 0), 0.8)
	_tween.tween_callback(_end)


## Trevor, from the player sheet's first idle frame, so the character in the
## cutscene is exactly the one the player is about to control.
func _trevor() -> TextureRect:
	var sheet := load("res://assets/pixel/player_sheet.png") as Texture2D
	var table_res := load("res://assets/pixel/player_sheet.json")
	var tr := TextureRect.new()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sheet != null and table_res != null:
		var cell: Array = table_res.data["cell"]
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0, 0, int(cell[0]), int(cell[1]))
		tr.texture = atlas
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(int(cell[0]), int(cell[1])) * SPRITE_SCALE
		tr.size = tr.custom_minimum_size
		tr.pivot_offset = tr.size * 0.5
	_stage.add_child(tr)
	return tr


func _input(event: InputEvent) -> void:
	var skip := false
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		skip = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip = true
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_end()


func _end() -> void:
	if _skipped:
		return
	_skipped = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	finished.emit()
	queue_free()
