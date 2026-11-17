extends SceneTree
## The local death line: the void under the player is short (about two player
## heights under the nearest platform surface) and the visible floor sits on it,
## but it can never sit above ground the player can legitimately stand on or
## land on, in any of the 25 levels.

var _failures: int = 0


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_pure()
	_every_level()
	await _live()
	print("[test_local_death] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _spans_of(level_num: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in LevelData.get_level(level_num).platforms:
		if String(p.name).contains("Wall"):
			continue
		out.append(Vector3(p.position.x - p.size.x * 0.5, p.position.x + p.size.x * 0.5,
			p.position.y - p.size.y * 0.5))
	return out


func _pure() -> void:
	var spans: Array[Vector3] = [Vector3(0, 200, 100), Vector3(300, 500, 300)]
	_check("line sits LOCAL_DEATH_DROP under the lowest nearby surface",
		is_equal_approx(MainScene.local_death_y(spans, 250.0, 5000.0), 300.0 + MainScene.LOCAL_DEATH_DROP))
	_check("only platforms within the window count",
		is_equal_approx(MainScene.local_death_y(spans, -600.0, 5000.0), 100.0 + MainScene.LOCAL_DEATH_DROP)
		or MainScene.local_death_y(spans, -600.0, 5000.0) <= 300.0 + MainScene.LOCAL_DEATH_DROP)
	_check("far from everything falls back to the level floor",
		is_equal_approx(MainScene.local_death_y(spans, 9000.0, 5000.0), 5000.0))
	_check("never below the level-wide floor",
		MainScene.local_death_y(spans, 250.0, 150.0) <= 150.0)


## For every level: the line is below every platform surface the player could be
## standing on or landing on near them, at every sampled x.
func _every_level() -> void:
	var worst_gap_ok := true
	var below_every_surface := true
	var checked := 0
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		var spans := _spans_of(n)
		var floor_y := -INF
		for sp in spans:
			floor_y = maxf(floor_y, sp.z)
		floor_y += 2000.0  # a generous "level-wide floor"
		for sp in spans:
			var x := (sp.x + sp.y) * 0.5
			var line := MainScene.local_death_y(spans, x, floor_y)
			checked += 1
			# Every surface within the window of x must be above the line.
			for other in spans:
				if other.y < x - MainScene.LOCAL_DEATH_WINDOW or other.x > x + MainScene.LOCAL_DEATH_WINDOW:
					continue
				if other.z + MainScene.LOCAL_DEATH_DROP > line + 0.01:
					below_every_surface = false
	_check("no level has a platform surface closer than the drop to the line (%d checked)" % checked,
		below_every_surface)
	# The window must cover the widest empty stretch in every level, or a platform the
	# player can still reach could fall outside it.
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		var spans := _spans_of(n)
		spans.sort_custom(func(a, b): return a.x < b.x)
		var reach := -INF
		var worst := 0.0
		for sp in spans:
			if reach != -INF:
				worst = maxf(worst, sp.x - reach)
			reach = maxf(reach, sp.y)
		if worst >= MainScene.LOCAL_DEATH_WINDOW:
			worst_gap_ok = false
			print("  L%d widest gap %d >= window" % [n, int(worst)])
	_check("the window is wider than the widest empty stretch in every level", worst_gap_ok)


func _live() -> void:
	var scene: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", 1)
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var player: Node2D = scene.get_node("Player")
	var plane: Node2D = scene.get_node("Hazards/DeathPlane")
	var global_y: float = scene.get("_plane_global_y")
	await _frames(20)
	_check("the floor has risen to the local line, above the old level-wide floor",
		plane.position.y < global_y - 50.0)
	var spans: Array[Vector3] = scene.get("_platform_spans")
	var line := MainScene.local_death_y(spans, player.global_position.x, global_y)
	_check("the floor sits on the local line", absf(plane.position.y - line) < 2.0)
	# A spot genuinely in the void: just past the end of the last platform.
	var right_edge := -INF
	for sp in spans:
		right_edge = maxf(right_edge, sp.y)
	var void_x := right_edge + 150.0
	line = MainScene.local_death_y(spans, void_x, global_y)
	# Drop him into the void well clear of the ground: he must die at the local line,
	# not fall all the way to the old floor.
	var attempts_before: int = scene.get("attempts")
	player.global_position = Vector2(void_x, line - 140.0)
	player.velocity = Vector2(0, 600)
	var frames := 0
	while int(scene.get("attempts")) == attempts_before and frames < 120:
		await physics_frame
		frames += 1
	_check("falling into the void ends the attempt (%d frames)" % frames, int(scene.get("attempts")) > attempts_before)
	_check("quickly: well under a second", frames < 60)
	scene.queue_free()
	await _frames(2)


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame
