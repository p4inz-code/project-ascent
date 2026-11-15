extends SceneTree
## Lists what a level actually builds (headless): node classes under Hazards / Terrain and the def's extras.
func _initialize() -> void:
	_run()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var levels: Array = []
	for s in a: levels.append(int(s))
	await physics_frame
	for lv in levels:
		var d := LevelData.get_level(lv)
		print("== L", lv, " ", d.name, " machine=", d.machine, " storm=", d.storm, " gates=", d.gates.size(), " pipes=", d.pipes.size(), " plate_gates=", d.plate_gates.size(), " checkpoints=", d.checkpoints.size(), " blades=", d.spinning_blades.size(), " lava=", d.lava_pits.size())
		var kinds := {}
		for p in d.platforms:
			kinds[p.kind] = int(kinds.get(p.kind, 0)) + 1
		print("   platform kinds ", kinds)
		var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
		main.set("level_number", lv)
		root.add_child(main)
		for i in 6: await physics_frame
		for holder in ["Hazards", "Terrain"]:
			var h := main.get_node_or_null(holder)
			var c := {}
			if h != null:
				for n in h.get_children():
					var k := n.get_class() if n.get_script() == null else String(n.get_script().get_global_name())
					if k == "": k = n.name
					c[k] = int(c.get(k, 0)) + 1
			print("   ", holder, " ", c)
		var top := {}
		for n in main.get_children():
			var k2 := String(n.get_script().get_global_name()) if n.get_script() != null else n.get_class()
			top[k2 if k2 != "" else n.name] = 1
		print("   main children ", top.keys())
		main.queue_free()
		await process_frame
	quit()
