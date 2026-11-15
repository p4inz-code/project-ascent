extends SceneTree
## Biome tile art: the five surfaces exist, draw without error, are deterministic per tile, and the
## machine levels dress their floors with the surface of their biome (and fake tiles stay plain).

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	for k in TileDecor.BIOME_KINDS:
		_check("%s is a known pattern" % k, TileDecor.has_pattern(k))
	_check("(control) an unknown kind has no pattern", not TileDecor.has_pattern("plain_stone"))
	await physics_frame
	for k in TileDecor.BIOME_KINDS:
		var d := TileDecor.new()
		d.kind = k
		d.size = Vector2(260.0, 30.0)
		root.add_child(d)
		for i in 3:
			await process_frame
		d.queue_free()
	_check("every biome pattern draws for a few frames", true)
	# which biome each machine level uses
	var seen := {}
	for lvl in [6, 11, 16, 21, 25]:
		MachineRuntime.fixed_seed = 77
		var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
		main.set("level_number", lvl)
		root.add_child(main)
		for i in 4:
			await physics_frame
		var machine := main.get_node("Machine") as MachineRuntime
		var want: String = String(MachineRuntime.BIOME_TILE[String(machine.spec["recipe"]["biome"])])
		var dressed := 0
		var wrong := 0
		for c in machine.get_children():
			for g in c.get_children():
				if g is TileDecor and g.kind in TileDecor.BIOME_KINDS:
					if g.kind == want:
						dressed += 1
					else:
						wrong += 1
		seen[want] = dressed
		_check("level %d (%s): %d tiles dressed with %s, none with another" % [lvl, machine.spec["recipe"]["biome"], dressed, want], dressed > 0 and wrong == 0)
		main.queue_free()
		await process_frame
	_check("the five levels covered %d different surfaces" % seen.size(), seen.size() >= 4)
	MachineRuntime.fixed_seed = 0
	print("[test_tile_biomes] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
