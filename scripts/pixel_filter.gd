class_name PixelFilter
extends CanvasLayer
## Snaps the WORLD to a chunky pixel grid so the vector terrain, hazards and
## backdrop read as one pixel-art scene alongside the sprites.
##
## It sits on a layer below the HUD (100), the death flash (120) and the pause
## menu (200), so all UI stays crisp at full resolution: only gameplay is
## quantised. A real 640x360 viewport would have forced a rebuild of every UI
## screen; this gets the same look without touching them.
##
## One art pixel is ART_SCALE world units (see PlayerVisuals.ART_SCALE and
## docs/ART.md). The block size in SCREEN pixels follows the window, so the
## grid stays locked to the art however the window is resized.

const ART_SCALE: float = 3.0
const SHADER := preload("res://shaders/pixelate.gdshader")

var _material: ShaderMaterial


func _ready() -> void:
	layer = 10
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var rect := ColorRect.new()
	rect.material = _material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	get_tree().root.size_changed.connect(_update_block)
	var gs := get_node_or_null("/root/GameSettings")
	if gs != null and gs.has_signal("settings_changed"):
		gs.settings_changed.connect(_update_block)
	_update_block()


func _update_block() -> void:
	var win := get_window()
	var visible_h := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var screen_h := float(win.size.y)
	var base_block := maxf(ART_SCALE * screen_h / visible_h, 1.0)
	var gs := get_node_or_null("/root/GameSettings")
	var mode: int = int(gs.pixel_mode) if gs != null else 1
	var dither: float = float(gs.pixel_dither) if gs != null else 1.0
	var levels: float = float(gs.pixel_levels) if gs != null else 20.0
	var scan: float = float(gs.scanlines) if gs != null else 0.0
	match mode:
		0:
			# Smooth: no snapping, no banding, no dither. Scanlines can still apply.
			_material.set_shader_parameter("block_px", 1.0)
			_material.set_shader_parameter("levels", 255.0)
			_material.set_shader_parameter("dither_strength", 0.0)
		2:
			_material.set_shader_parameter("block_px", base_block * 2.0)
			_material.set_shader_parameter("levels", levels)
			_material.set_shader_parameter("dither_strength", dither)
		_:
			_material.set_shader_parameter("block_px", base_block)
			_material.set_shader_parameter("levels", levels)
			_material.set_shader_parameter("dither_strength", dither)
	_material.set_shader_parameter("scanline_strength", scan)
	var cvd_kind: int = int(gs.get_reg("a11y_colorblind")) if gs != null and gs.has_method("get_reg") else 0
	_material.set_shader_parameter("cvd", ColorVision.matrix(cvd_kind))
