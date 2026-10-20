extends SceneTree
## Screenshots of the M1 arena: idle, mid-slash on a drone, hurt (health bar), spikes.
## Run WITHOUT --headless:  Godot --path <project> --script res://tools/capture_arena.gd -- <out dir>
const WINDOW_SIZE := Vector2i(1280, 720)
var _out := "user://arena"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	_run()

func _shot(name: String) -> void:
	for i in 3: await process_frame
	get_root().get_texture().get_image().save_png(_out + "/" + name + ".png")
	print("[arena] ", name)

func _run() -> void:
	DisplayServer.window_set_size(WINDOW_SIZE)
	DirAccess.make_dir_recursive_absolute(_out)
	for i in 3: await process_frame
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", LevelData.ARENA_LEVEL)
	get_root().add_child(scene)
	for i in 30: await physics_frame
	var p: Player = scene.get_node("Player")
	var atk: PlayerAttack = p.get_node("Attack")
	await _shot("1_start")
	var d: Drone = scene.get_node("Hazards/Drone_0")
	d.set_physics_process(false)
	p.global_position = d.global_position + Vector2(-60, 0)
	p.velocity = Vector2.ZERO
	for i in 20: await physics_frame
	atk.aim_override = Vector2.RIGHT
	atk.try_slash()
	for i in 3: await physics_frame
	await _shot("2_slash_kill")
	p.health.take_hit()
	for i in 6: await physics_frame
	await _shot("3_hurt_1")
	p.health.tick(1.5)
	p.health.take_hit()
	for i in 6: await physics_frame
	await _shot("4_hurt_2_amber")
	p.health.reset()
	p.global_position = Vector2(2850, 740)
	p.velocity = Vector2.ZERO
	for i in 60: await physics_frame
	await _shot("5_spikes")
	quit(0)
