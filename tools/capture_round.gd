extends SceneTree
## One short visual pass: a handful of frames of the real game, for checking fixes against what the owner saw.
## Run WITHOUT --headless:  Godot --path . --script res://tools/capture_round.gd -- <out dir> <shot> <shot> ...
## A shot is  level:x:y  (the player is parked there, physics off) or  fx  (a sheet of the transition covers).
var _out := "user://round"


func _initialize() -> void:
	_run()


func _shot(name: String) -> void:
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png(_out + "/" + name + ".png")


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for i in 3:
		await process_frame
	var current: Node = null
	var current_level := -1
	for k in range(1, a.size()):
		var s := String(a[k])
		if s == "fx":
			if current != null:
				current.queue_free()
				current = null
				current_level = -1
				await process_frame
			var bg := ColorRect.new()
			bg.color = Color(0.25, 0.3, 0.4)
			bg.size = Vector2(1920, 1080)
			root.add_child(bg)
			for st in TransitionFx.STYLE_NAMES.size():
				var fx := TransitionFx.new()
				root.add_child(fx)
				fx.set_anchors_preset(Control.PRESET_TOP_LEFT)
				fx.size = Vector2(1920, 1080)
				fx.scale = Vector2(0.25, 0.25)
				fx.position = Vector2(float(st % 4) * 480.0, float(st / 4) * 540.0)
				fx.clip_contents = true
				fx.style = st
				fx.cover = 0.55
			await _shot("fx_covers")
			continue
		var parts := s.split(":")
		var lv := int(parts[0])
		if lv != current_level:
			if current != null:
				current.queue_free()
				await process_frame
			MachineRuntime.fixed_seed = 4242
			current = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
			current.set("level_number", lv)
			root.add_child(current)
			for i in 30:
				await physics_frame
			current_level = lv
		var p: Player = current.get_node("Player")
		p.set_physics_process(false)
		p.global_position = Vector2(float(parts[1]), float(parts[2]))
		for i in 50:
			await physics_frame
		await _shot("L%d_%s_%s" % [lv, parts[1], parts[2]])
	quit()
