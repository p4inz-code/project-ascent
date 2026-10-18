class_name CharacterPreview
extends Control
## A live preview of Trevor with the current character choices, for the
## Settings page. Uses the very same frames and palette material as the in-game
## sprite, so what you see here is exactly what you get in the level.
##
## It cycles through a few animations so every accessory is seen from the side
## it is worn on: idle, run, wall slide, dash.

const SCALE := 9.0
const CYCLE := ["idle", "run", "idle", "dash", "wall"]
const CYCLE_TIME := 1.8

var _sprite: AnimatedSprite2D
var _material: ShaderMaterial
var _sheet_path: String = ""
var _time: float = 0.0
var _index: int = 0
var _pedestal: ColorRect


func _init() -> void:
	custom_minimum_size = Vector2(240, 260)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color(0.05, 0.07, 0.12)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_pedestal = ColorRect.new()
	_pedestal.color = Color(0.13, 0.15, 0.24)
	add_child(_pedestal)
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/palette_swap.gdshader")
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.material = _material
	_sprite.scale = Vector2(SCALE, SCALE)
	_sprite.centered = true
	add_child(_sprite)
	resized.connect(_layout)
	refresh()
	_layout()


func _layout() -> void:
	if _sprite == null:
		return
	# 20-row cell, feet on row 18: stand the feet on the pedestal.
	var floor_y := size.y - 44.0
	_sprite.position = Vector2(size.x * 0.5, floor_y - 9.0 * SCALE + SCALE)
	_pedestal.position = Vector2(size.x * 0.5 - 70.0, floor_y)
	_pedestal.size = Vector2(140.0, 12.0)


## Re-read the player's choices and show them.
func refresh() -> void:
	var gs := get_node_or_null("/root/GameSettings")
	var path: String = gs.sheet_path() if gs != null and gs.has_method("sheet_path") \
		else "res://assets/pixel/player_sheet.png"
	if path != _sheet_path:
		var frames := PlayerVisuals.build_frames(path)
		if frames != null:
			_sprite.sprite_frames = frames
			_sheet_path = path
			_sprite.play(CYCLE[_index])
	_material.set_shader_parameter("suit", gs.get_player_color() if gs != null else Color(0.42, 0.78, 1.0))
	PlayerVisuals.apply_look(_material, gs)


## Name of the animation currently showing (for tests).
func current_animation() -> String:
	return String(_sprite.animation) if _sprite != null else ""


func advance(delta: float) -> void:
	_time += delta
	if _time >= CYCLE_TIME:
		_time = 0.0
		_index = (_index + 1) % CYCLE.size()
		if _sprite != null and _sprite.sprite_frames != null:
			_sprite.play(CYCLE[_index])


func _process(delta: float) -> void:
	advance(delta)
