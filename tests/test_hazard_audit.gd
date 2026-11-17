extends SceneTree
## Every lethal obstacle must be meaningful: not stacked on another, not firing
## through another, and visibly held up by something. Checked on the real level data
## (after the automatic repair), with synthetic negative controls.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_synthetic()
	_all_levels()
	await _supports()
	print("[test_hazard_audit] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame


func _empty_level():
	var def := LevelData.LevelDef.new()
	def.platforms = [] as Array[LevelData.PlatformDef]
	return def


func _synthetic() -> void:
	var def = _empty_level()
	def.spinning_blades = [
		LevelData.SpinningBladeDef.new(Vector2(500, 300), 70.0, 3.0),
		LevelData.SpinningBladeDef.new(Vector2(540, 310), 65.0, 3.0),
	] as Array[LevelData.SpinningBladeDef]
	_check("two blades on top of each other are flagged", not HazardAudit.problems(def).is_empty())
	var notes := HazardAudit.repair(def, [])
	_check("repair removes the stacked one", def.spinning_blades.size() == 1 and not notes.is_empty())
	_check("and the level is then clean", HazardAudit.problems(def).is_empty())

	var d2 = _empty_level()
	d2.spinning_blades = [LevelData.SpinningBladeDef.new(Vector2(400, 300), 70.0, 3.0)] as Array[LevelData.SpinningBladeDef]
	d2.shooters = [LevelData.ShooterDef.new(Vector2(700, 300), Vector2(-1, 0), 2.2)] as Array[LevelData.ShooterDef]
	_check("a dart lane straight through a blade is flagged", not HazardAudit.problems(d2).is_empty())
	HazardAudit.repair(d2, [])
	_check("repair slides the lane clear, keeping the shooter", d2.shooters.size() == 1 and HazardAudit.problems(d2).is_empty())
	_check("the lane moved less than the cap", absf(d2.shooters[0].position.y - 300.0) <= HazardAudit.MAX_SHIFT)

	var d3 = _empty_level()
	d3.shooters = [LevelData.ShooterDef.new(Vector2(700, 300), Vector2(-1, 0), 2.2)] as Array[LevelData.ShooterDef]
	_check("a lone shooter is clean", HazardAudit.problems(d3).is_empty())


func _all_levels() -> void:
	var bad := 0
	var hazards := 0
	var gates_close := 0
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		var lv := LevelData.get_level(n)
		hazards += lv.spinning_blades.size() + lv.pendulums.size() + lv.shooters.size() + lv.gates.size()
		var probs := HazardAudit.problems(lv)
		if not probs.is_empty():
			bad += 1
			print("  L%d: %s" % [n, "; ".join(probs)])
		# Gates keep their distance from every other lethal obstacle.
		for g in lv.gates:
			var gx: float = (g[0] as Vector2).x
			for b in lv.spinning_blades:
				if absf(gx - b.position.x) < b.radius + GateRules.CLEAR_FROM_HAZARD - 1.0:
					gates_close += 1
			for p in lv.pendulums:
				if absf(gx - p.position.x) < p.arm_length * sin(deg_to_rad(p.max_angle_deg)) + GateRules.CLEAR_FROM_HAZARD - 1.0:
					gates_close += 1
			for s in lv.shooters:
				if absf(gx - s.position.x) < 40.0 + GateRules.CLEAR_FROM_HAZARD - 1.0:
					gates_close += 1
	_check("no level has stacked or blocked obstacles (%d obstacles)" % hazards, bad == 0)
	_check("no timing gate sits on another obstacle", gates_close == 0)


func _supports() -> void:
	var unsupported := 0
	var checked := 0
	for n in [12, 16, 18, 20, 22, 25]:
		var scene := (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
		scene.set("level_number", n)
		root.add_child(scene)
		await _step(4)
		var support: HazardSupport = scene.get_node_or_null("Hazards/HazardSupport")
		if support == null:
			unsupported += 1
		else:
			var lv := LevelData.get_level(n)
			var want := lv.spinning_blades.size() + lv.pendulums.size() + lv.shooters.size() + lv.gates.size() * 2
			checked += 1
			if not support.all_supported() or support.run_count() != want:
				unsupported += 1
				print("  L%d: runs=%d want=%d supported=%s" % [n, support.run_count(), want, support.all_supported()])
		scene.queue_free()
		await _step(2)
	_check("every hazard in sampled levels is visibly held up (%d levels)" % checked, unsupported == 0)

	# Negative control: a hazard far from any platform has no anchor.
	var rects: Array[Rect2] = [Rect2(0, 400, 200, 40)]
	var anchors := HazardSupport.anchors_for(Vector2(2000, 100), rects, 2)
	_check("a hazard with no platform in reach finds no anchor", anchors.is_empty())
	var near := HazardSupport.anchors_for(Vector2(300, 380), rects, 2)
	_check("one next to a platform does", not near.is_empty())
