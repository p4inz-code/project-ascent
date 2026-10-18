class_name NpcSprites
extends RefCounted
## Builds the animated pixel sprites for the chase NPCs (the Warden and its Sparks)
## from their one-row sheets. Same grid as everything else: nearest filtering,
## whole-number scale.

const WARDEN := "res://assets/pixel/warden_sheet.png"
const SPARK := "res://assets/pixel/spark_sheet.png"
const SCALE := 3.0


static func make(sheet_path: String, cell: Vector2i, frame_count: int = 4, fps: float = 8.0) -> AnimatedSprite2D:
	var sheet := load(sheet_path) as Texture2D
	if sheet == null:
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", fps)
	frames.set_animation_loop("idle", true)
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * cell.x, 0, cell.x, cell.y)
		frames.add_frame("idle", atlas)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.centered = true
	sprite.play("idle")
	return sprite
