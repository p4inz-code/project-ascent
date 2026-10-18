class_name LiquidFill
extends RefCounted
## Builds the shaded body of a pool (lava, acid or water) as a ColorRect. One
## palette table, one shader, so every pool in the game moves and looks related.

enum Style { LAVA, ACID, WATER }

const SHADER := preload("res://shaders/liquid.gdshader")

const PALETTES := {
	Style.LAVA: {
		"deep": Color(0.20, 0.025, 0.02), "mid": Color(0.80, 0.20, 0.05),
		"hot": Color(1.0, 0.80, 0.28), "crust": Color(0.09, 0.03, 0.03),
		"crust_level": 0.56, "glow": 1.0, "speed": 0.10, "cell": 46.0,
	},
	Style.ACID: {
		"deep": Color(0.03, 0.16, 0.05), "mid": Color(0.22, 0.70, 0.14),
		"hot": Color(0.80, 1.0, 0.40), "crust": Color(0.04, 0.18, 0.06),
		"crust_level": 1.5, "glow": 1.15, "speed": 0.16, "cell": 38.0,
	},
	Style.WATER: {
		"deep": Color(0.03, 0.10, 0.24), "mid": Color(0.12, 0.40, 0.72),
		"hot": Color(0.62, 0.88, 1.0), "crust": Color(0.04, 0.12, 0.26),
		"crust_level": 1.5, "glow": 0.8, "speed": 0.12, "cell": 64.0,
	},
}


static func make(size: Vector2, style: Style, seed_value: float = 0.0) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material_for(size, style, seed_value)
	return rect


static func material_for(size: Vector2, style: Style, seed_value: float = 0.0) -> ShaderMaterial:
	var pal: Dictionary = PALETTES[style]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("deep", pal["deep"])
	mat.set_shader_parameter("mid", pal["mid"])
	mat.set_shader_parameter("hot", pal["hot"])
	mat.set_shader_parameter("crust", pal["crust"])
	mat.set_shader_parameter("crust_level", pal["crust_level"])
	mat.set_shader_parameter("glow", pal["glow"])
	mat.set_shader_parameter("speed", pal["speed"])
	mat.set_shader_parameter("cell_px", pal["cell"])
	mat.set_shader_parameter("size_px", size)
	mat.set_shader_parameter("seed", seed_value)
	return mat
