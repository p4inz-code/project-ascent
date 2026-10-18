class_name PixelBackdrop
extends Control
## Full-rect tiled stone wall for full-screen pages (Settings, Controls, About).
## The same grayscale tile the world platforms use, drawn on the UI pixel grid
## (one art pixel = UITheme.PX screen pixels) and tinted dark so text on top of
## it stays readable. A vignette darkens the edges to pull the eye to the centre.

const TILE_PATH := "res://assets/pixel/stone_tile.png"

@export var tint: Color = Color(0.13, 0.16, 0.24)

var _tile: Texture2D


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	_tile = load(TILE_PATH) as Texture2D
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.07))
	if _tile == null:
		return
	var step := float(_tile.get_width() * UITheme.PX)
	var y := 0.0
	while y < size.y:
		var x := 0.0
		while x < size.x:
			draw_texture_rect(_tile, Rect2(x, y, step, step), false, tint)
			x += step
		y += step
	# Vignette: four soft bands, so the centre column pops.
	var edge := Color(0.0, 0.0, 0.03, 0.55)
	var band := minf(size.x, size.y) * 0.18
	for i in 6:
		var a := edge.a * (1.0 - float(i) / 6.0)
		var c := Color(edge.r, edge.g, edge.b, a)
		var t := band / 6.0
		draw_rect(Rect2(0, i * t, size.x, t), c)
		draw_rect(Rect2(0, size.y - (i + 1) * t, size.x, t), c)
		draw_rect(Rect2(i * t, 0, t, size.y), c)
		draw_rect(Rect2(size.x - (i + 1) * t, 0, t, size.y), c)
