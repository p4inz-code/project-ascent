extends SceneTree
## Hero animation set: every animation in the design bible exists on the sheet
## with the right frame counts, and PlayerVisuals picks the right one from real
## controller state (driven with real physics and Input actions, not mocks).

var _failures: int = 0
var _player: Player

## name -> minimum frame count the bible requires.
const REQUIRED := {
	"idle": 6, "breathe": 4, "run": 8, "skid": 2, "jump": 2, "apex": 1, "fall": 2,
	"land": 3, "wall": 2, "walljump": 3, "dash": 3, "slide": 2, "pound": 3,
	"spin": 6, "grapple": 2, "ledge": 3, "hurt": 2, "death": 8, "respawn": 6,
}


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_sheet()
	await _selection()
	await _respawn_and_echo()
	print("[test_animations] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _solid(pos: Vector2, size: Vector2) -> StaticBody2D:
	var b := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	c.shape = r
	b.add_child(c)
	b.collision_layer = 3
	b.position = pos
	root.add_child(b)
	return b


func _spawn(pos: Vector2) -> Player:
	var p: Player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(p)
	p.global_position = pos
	return p


func _visuals() -> PlayerVisuals:
	return _player.get_node("Visuals") as PlayerVisuals


func _release() -> void:
	for a in ["move_left", "move_right", "jump", "dash", "slide"]:
		Input.action_release(a)


func _sheet() -> void:
	var table: Dictionary = load("res://assets/pixel/player_sheet.json").data
	var anims: Dictionary = table["anims"]
	for name in REQUIRED:
		var have: int = int(anims.get(name, {}).get("frames", 0))
		_check("sheet has '%s' with >= %d frames (has %d)" % [name, REQUIRED[name], have],
			have >= int(REQUIRED[name]))
	# Frames must not be blank or identical copies where motion is promised.
	var sheet := load("res://assets/pixel/player_sheet.png") as Texture2D
	var img := sheet.get_image()
	var cell := Vector2i(int(table["cell"][0]), int(table["cell"][1]))
	for name in ["run", "death", "respawn", "spin"]:
		var info: Dictionary = anims[name]
		var seen := {}
		for i in int(info["frames"]):
			var region := img.get_region(Rect2i(i * cell.x, int(info["row"]) * cell.y, cell.x, cell.y))
			seen[region.get_data().hex_encode().hash()] = true
		_check("'%s' frames are not all identical" % name, seen.size() > 1)


## Run a scenario and return the animation PlayerVisuals settled on.
func _anim() -> String:
	return String((_visuals().get_node("../PixelSprite") as AnimatedSprite2D).animation)


func _selection() -> void:
	var ground := _solid(Vector2(0, 400), Vector2(6000, 40))
	_player = _spawn(Vector2(-1500, 340))
	await _step(12)
	_check("standing still -> idle", _anim() == "idle")

	# Long idle -> breathe.
	await _step(int(PlayerVisuals.IDLE_BREATHE_AFTER * 60.0) + 20)
	_check("after a long stand -> breathe", _anim() == "breathe")
	await _step(60)
	_check("breathe plays once, then returns to idle", _anim() == "idle")

	Input.action_press("move_right", 1.0)
	await _step(30)
	_check("running -> run", _anim() == "run")

	# Brake: release to the OPPOSITE direction while at speed.
	Input.action_release("move_right")
	Input.action_press("move_left", 1.0)
	await _step(2)
	_check("holding the opposite way at speed -> skid", _anim() == "skid")
	Input.action_release("move_left")
	await _step(40)

	# Jump arc: rise, apex, fall.
	Input.action_press("jump", 1.0)
	await _step(5)
	var saw := {}
	for _i in 80:
		await physics_frame
		saw[_anim()] = true
		if _player.is_on_floor():
			break
	Input.action_release("jump")
	_check("a jump shows the rise", saw.has("jump"))
	_check("a jump shows the apex", saw.has("apex"))
	_check("a jump shows the fall", saw.has("fall"))
	await _step(60)

	# Dash.
	Input.action_press("move_right", 1.0)
	await _step(6)
	Input.action_press("dash", 1.0)
	await _step(3)
	_check("dashing -> dash", _anim() == "dash")
	Input.action_release("dash")
	Input.action_release("move_right")
	await _step(60)

	# Slide (needs a run-up).
	Input.action_press("move_right", 1.0)
	await _step(30)
	Input.action_press("slide", 1.0)
	await _step(3)
	_check("sliding -> slide", _anim() == "slide")
	Input.action_release("slide")
	Input.action_release("move_right")
	await _step(60)

	_release()
	_player.queue_free()
	ground.queue_free()
	await _step(2)

	# Wall slide + wall jump.
	var wall := _solid(Vector2(60, 0), Vector2(40, 3000))
	_player = _spawn(Vector2(10, -600))
	await _step(4)
	Input.action_press("move_right", 1.0)
	var wall_seen := false
	for _i in 90:
		await physics_frame
		if _anim() == "wall":
			wall_seen = true
			break
	_check("falling against a wall -> wall slide", wall_seen)
	Input.action_press("jump", 1.0)
	await _step(3)
	Input.action_release("jump")
	Input.action_release("move_right")
	var wj := false
	for _i in 10:
		await physics_frame
		if _anim() == "walljump":
			wj = true
	_check("a wall jump plays the walljump animation", wj)
	_release()
	_player.queue_free()
	wall.queue_free()
	await _step(2)


func _respawn_and_echo() -> void:
	var ground := _solid(Vector2(0, 400), Vector2(6000, 40))
	_player = _spawn(Vector2(-300, 340))
	await _step(10)
	var v := _visuals()
	var fell_at: Vector2 = _player.global_position
	v.play_death_echo(fell_at, 1)
	_check("a death leaves an echo behind", v.echo_visible())
	var echo := v.get_node("DeathEcho") as AnimatedSprite2D
	_check("the echo plays 'death'", echo.animation == "death")
	_check("the echo stays where he fell", echo.global_position.distance_to(fell_at) < 80.0)

	# Teleport the real player away (what _respawn does): the echo must not follow.
	_player.global_position = fell_at + Vector2(900, 0)
	v.reset_state()
	v.play_respawn()
	await _step(3)
	_check("the new life plays 'respawn'", _anim() == "respawn")
	_check("the echo did not follow the player", echo.global_position.distance_to(fell_at) < 80.0)
	await _step(int(PlayerVisuals.RESPAWN_ANIM_TIME * 60.0) + 12)
	_check("respawn hands back to idle", _anim() == "idle")
	await _step(90)
	_check("the echo finishes and hides", not v.echo_visible())
	_player.queue_free()
	ground.queue_free()
	await _step(2)
