class_name PlayerVisuals
extends Node2D
## Non-authoritative visual feedback for the player: the pixel-art sprite, its
## animation selection, and a trail of afterimages while dashing.
##
## Deliberately separate from `scripts/player.gd`: nothing here may affect
## physics. It reads the controller through its public `is_*()` / `landed` API,
## so a bug in here can make the game look wrong but never make it play wrong.
##
## The scene's vector `Body` polygon is kept as an invisible tint carrier: the
## palette setting, the dash flash and the tests all speak in `Body.color`, and
## the visible pixel sprite follows it through a palette-swap shader. Keeping
## that contract meant the sprite swap changed what is drawn without changing
## how anything else talks to the player.
##
## The ghost trail uses a fixed pre-allocated pool rather than instancing nodes
## per frame, which keeps the "node count is flat during play" property the
## performance audit relies on (see docs/ARCHITECTURE.md → Performance).

## Fall speed (px/s) that produces the full landing beat. Slower landings scale down.
@export var max_impact_speed: float = 700.0
## How long the landing frame holds, as a fraction of a full-impact landing.
@export_range(0.0, 0.6) var squash_amount: float = 0.26
## Seconds to recover from a landing frame back to neutral.
@export var recover_time: float = 0.13
## Afterimages in the dash trail. Fixed pool: raise for a longer trail.
@export var ghost_count: int = 8
## Seconds each afterimage takes to fade out.
@export var ghost_fade_time: float = 0.26
## Starting opacity of an afterimage.
@export_range(0.0, 1.0) var ghost_alpha: float = 0.62
## Horizontal smear applied to each afterimage. A dash only covers ~90 px, so
## eight un-stretched images sit almost on top of each other and read as
## nothing; widening them joins the trail into one streak.
@export_range(1.0, 3.0) var ghost_stretch: float = 1.6
## Body colour while dashing. The dash is the most powerful verb in the moveset
## and previously had no visual signature at all — the player just moved faster.
@export var dash_tint: Color = Color(0.86, 0.96, 1.0, 1.0)
## Vertical squash applied to afterimages, so the trail reads as motion.
@export_range(0.0, 0.4) var stretch_amount: float = 0.14

## World units per art pixel. Must match docs/ART.md and the camera zoom.
const ART_SCALE: float = 3.0
const SHEET_PATH := "res://assets/pixel/player_sheet.png"
const TABLE_PATH := "res://assets/pixel/player_sheet.json"
const SWAP_SHADER := preload("res://shaders/palette_swap.gdshader")

## Absolute draw layer for the afterimages: above the terrain (z 0), below the
## player (z 2, set on the player scene root). Kept as a constant so the two
## halves of that contract are findable from one place.
const GHOST_Z: int = 1

var _player: Player
var _body: Polygon2D
## The Body polygon's authored colour, restored when a dash ends.
var _base_color: Color = Color.WHITE
## Landing beat, decaying to zero; drives the "land" frame.
var _impact: float = 0.0
## Camera shake helper, attached in _attach_camera_shake().
var _shake: CameraShake = null
var _sprite: AnimatedSprite2D = null
var _material: ShaderMaterial = null
var _ghosts: Array[Polygon2D] = []
var _ghost_sprites: Array[Sprite2D] = []
var _ghost_life: PackedFloat32Array = PackedFloat32Array()
var _next_ghost: int = 0
## One reusable cue label (never per-event nodes: the node count stays flat).
var _cue: Label = null
var _cue_tween: Tween = null


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_warning("PlayerVisuals expects to be a child of a Player node.")
		return
	_body = _player.get_node_or_null("Body") as Polygon2D
	if _body == null:
		push_warning("PlayerVisuals could not find the Player's Body polygon.")
		return
	_apply_player_color()
	_base_color = _body.color
	_hide_vector_body()
	_build_pixel_sprite()
	_player.landed.connect(_on_landed)
	_player.slide_refused.connect(_on_slide_refused)
	_build_cue()
	_build_ghost_pool()
	_attach_camera_shake()


## Give the player a CameraShake sibling, created here rather than authored
## into player.tscn so the scene file stays untouched and any Player instance
## (including the ones headless tests spawn bare) picks it up automatically.
func _attach_camera_shake() -> void:
	if _player.get_node_or_null("CameraShake") != null:
		return
	var shake := CameraShake.new()
	shake.name = "CameraShake"
	# Deferred: this runs from PlayerVisuals._ready(), which happens while the
	# Player is still setting up its own children, and a direct add_child()
	# there fails outright ("parent node is busy setting up children") —
	# leaving the shake node never attached and the whole effect silently
	# dead. Caught by the boot test printing that error.
	_player.add_child.call_deferred(shake)
	_shake = shake


## Recolour the body from the player's chosen palette entry. Runs before
## _base_color is captured so the dash-tint restore, the afterimage pool and
## every other consumer all inherit the chosen colour rather than the
## scene-authored blue.
func _apply_player_color() -> void:
	var gs := get_node_or_null("/root/GameSettings")
	if gs == null or not gs.has_method("get_player_color"):
		return
	_body.color = gs.get_player_color()


## The vector body stays in the tree (tint carrier, test contract) but must not
## draw: the pixel sprite is the visible character. self_modulate leaves the
## children alone, so the Visor is hidden the same way explicitly.
func _hide_vector_body() -> void:
	_body.self_modulate = Color(1, 1, 1, 0)
	for child in _body.get_children():
		if child is CanvasItem:
			(child as CanvasItem).self_modulate = Color(1, 1, 1, 0)


func _build_pixel_sprite() -> void:
	var sheet := load(SHEET_PATH) as Texture2D
	var table_res := load(TABLE_PATH)
	if sheet == null or table_res == null:
		push_warning("PlayerVisuals: pixel sheet or frame table missing; falling back to the vector body.")
		_body.self_modulate = Color.WHITE
		return
	var table: Dictionary = table_res.data
	var cell := Vector2i(int(table["cell"][0]), int(table["cell"][1]))

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name in table["anims"]:
		var info: Dictionary = table["anims"][anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(info["fps"]))
		frames.set_animation_loop(anim_name, bool(info["loop"]))
		for i in int(info["frames"]):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * cell.x, int(info["row"]) * cell.y, cell.x, cell.y)
			frames.add_frame(anim_name, atlas)

	_material = ShaderMaterial.new()
	_material.shader = SWAP_SHADER
	_material.set_shader_parameter("suit", _body.color)

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "PixelSprite"
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.material = _material
	_sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	# Feet sit on art row 18, so the cell's bottom edge is row 19: place that
	# edge on the collider's floor (+26) rather than centring the whole cell.
	var half := Vector2(cell) * 0.5
	_sprite.position = Vector2(0.0, 26.0 - (19.0 - half.y) * ART_SCALE)
	_sprite.play("idle")
	_player.add_child.call_deferred(_sprite)


## Pre-allocate the afterimages once. They are `top_level` so they stay where
## they were stamped instead of riding along with the moving player.
##
## Each ghost is a Polygon2D (the existing pool contract: `color.a` is the fade,
## `visible` is liveness) that does not draw itself; a child Sprite2D shows the
## stamped frame. Depth needs absolute z: a *relative* -1 would put the ghosts
## behind the backdrop's ridge polygons and they would never be seen.
func _build_ghost_pool() -> void:
	_ghost_life.resize(ghost_count)
	for i in ghost_count:
		var ghost := Polygon2D.new()
		ghost.polygon = _body.polygon
		ghost.color = _body.color
		ghost.self_modulate = Color(1, 1, 1, 0)
		ghost.top_level = true
		ghost.visible = false
		ghost.z_as_relative = false
		ghost.z_index = GHOST_Z
		var spr := Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.material = _material
		spr.scale = Vector2(ART_SCALE, ART_SCALE)
		if _sprite != null:
			spr.position = _sprite.position
		ghost.add_child(spr)
		add_child(ghost)
		_ghosts.append(ghost)
		_ghost_sprites.append(spr)
		_ghost_life[i] = 0.0


## A small floating label above the head, reused for every cue. Created once.
func _build_cue() -> void:
	_cue = Label.new()
	_cue.name = "Cue"
	_cue.top_level = true
	_cue.z_as_relative = false
	_cue.z_index = 3
	_cue.visible = false
	_cue.add_theme_font_size_override("font_size", 26)
	_cue.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	_cue.add_theme_color_override("font_outline_color", Color(0.04, 0.07, 0.18))
	_cue.add_theme_constant_override("outline_size", 8)
	var font := load("res://assets/fonts/CyberpunkCraftpixPixel.otf") as Font
	if font != null:
		_cue.add_theme_font_override("font", font)
	add_child(_cue)


## Say something short above the player and let it drift up and fade.
func show_cue(text: String) -> void:
	if _cue == null or not is_instance_valid(_cue):
		return
	_cue.text = text
	_cue.reset_size()
	_cue.position = _player.global_position + Vector2(-_cue.size.x * 0.5, -96.0)
	_cue.modulate.a = 1.0
	_cue.visible = true
	if _cue_tween != null and _cue_tween.is_valid():
		_cue_tween.kill()
	_cue_tween = create_tween()
	_cue_tween.set_parallel(true)
	_cue_tween.tween_property(_cue, "position:y", _cue.position.y - 36.0, 0.9)
	_cue_tween.tween_property(_cue, "modulate:a", 0.0, 0.9).set_delay(0.35)
	_cue_tween.chain().tween_callback(func(): _cue.visible = false)


func _on_slide_refused() -> void:
	show_cue("RUN FIRST")


func _on_landed(fall_speed: float) -> void:
	var t := clampf(fall_speed / maxf(max_impact_speed, 1.0), 0.0, 1.0)
	_impact = maxf(_impact, t * squash_amount)
	# Only a genuinely hard landing shakes — every routine hop doing it would
	# make the whole game feel loose.
	if _shake != null and t > 0.55:
		_shake.add_trauma(t * 0.35)


## True while the player is actually descending against a wall — the same
## airborne + on-wall + falling + pressing-toward-the-wall conditions the
## controller uses to clamp the slide (see Player._is_wall_slide_active()).
## Without the direction check, this pose showed "gripping the wall" any time
## the player merely touched a wall while falling, even moving away from it
## or holding no input, while the actual slide clamp — which only engages
## while pressing in — left them falling at full speed underneath the pose.
func _is_wall_sliding() -> bool:
	if _player.is_on_floor() or _player.is_dashing():
		return false
	if not _player.is_on_wall_only():
		return false
	if _player.velocity.y <= 0.0:
		return false
	var direction := Input.get_axis("move_left", "move_right")
	return not is_zero_approx(direction) \
		and signi(direction) == -signi(_player.get_wall_normal().x)


## Which animation the controller's state calls for. Order is priority: a
## deliberate verb beats a locomotion state, which beats the idle default.
func _pick_animation() -> String:
	if _player.is_dashing():
		return "dash"
	if _player.is_sliding():
		return "slide"
	if _is_wall_sliding():
		return "wall"
	if not _player.is_on_floor():
		return "jump" if _player.velocity.y < 0.0 else "fall"
	if _impact > squash_amount * 0.08:
		return "land"
	if absf(_player.velocity.x) > 20.0:
		return "run"
	return "idle"


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	var dashing := _player.is_dashing()
	_update_trail(delta, dashing)
	_impact = move_toward(_impact, 0.0, delta / maxf(recover_time, 0.001) * squash_amount)

	# The dash reads as a flash of near-white; everything else is the base colour.
	_body.color = dash_tint if dashing else _base_color
	if _material != null:
		_material.set_shader_parameter("suit", _body.color)

	if _sprite == null or not is_instance_valid(_sprite):
		return
	var anim := _pick_animation()
	if _sprite.animation != anim:
		_sprite.play(anim)
	# Sprites face right in the sheet; flip for left. Never scale the sprite
	# non-uniformly: stretched pixels are the quickest way to break the look.
	_sprite.flip_h = _player.facing() < 0
	if _player.is_spinning():
		# A full rotation over the flourish window, in the facing direction.
		_sprite.rotation = TAU * _player.spin_progress() * float(_player.facing())
	else:
		_sprite.rotation = 0.0


func _update_trail(delta: float, dashing: bool) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs != null and not gs.afterimages:
		# Clear all ghosts when afterimages are disabled
		for i in _ghosts.size():
			if _ghost_life[i] > 0.0:
				_ghost_life[i] = 0.0
				_ghosts[i].visible = false
		return
	# Stamp every frame the dash is active, so a 0.14 s dash lays down roughly
	# eight images — one per pool slot.
	if dashing:
		_stamp_ghost()

	for i in _ghosts.size():
		if _ghost_life[i] <= 0.0:
			continue
		_ghost_life[i] = maxf(_ghost_life[i] - delta, 0.0)
		var ghost := _ghosts[i]
		var t := _ghost_life[i] / maxf(ghost_fade_time, 0.001)
		ghost.color.a = t * ghost_alpha
		_ghost_sprites[i].modulate.a = t * ghost_alpha
		ghost.visible = _ghost_life[i] > 0.0


func _stamp_ghost() -> void:
	if _ghosts.is_empty():
		return
	var ghost := _ghosts[_next_ghost]
	ghost.global_position = _player.global_position
	# The ghost's own scale x is signed by facing() so the child sprite (drawn
	# facing right) mirrors with the way the dash actually went.
	ghost.scale = Vector2(ghost_stretch * float(_player.facing()), 1.0 - stretch_amount)
	ghost.color = Color(dash_tint, ghost_alpha)
	var spr := _ghost_sprites[_next_ghost]
	if _sprite != null and is_instance_valid(_sprite):
		spr.texture = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
		spr.position = _sprite.position
	ghost.visible = true
	_ghost_life[_next_ghost] = ghost_fade_time
	_next_ghost = (_next_ghost + 1) % _ghosts.size()


## Clear all transient visual state. Called from the level controller on respawn
## so a new life never starts mid-landing, or with a stale pose or trailing
## ghosts from the old one.
func reset_state() -> void:
	_impact = 0.0
	if _body != null:
		_body.color = _base_color
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.rotation = 0.0
		_sprite.play("idle")
	for i in _ghosts.size():
		_ghost_life[i] = 0.0
		_ghosts[i].visible = false
