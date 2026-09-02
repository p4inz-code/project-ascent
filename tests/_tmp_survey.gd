extends SceneTree
## Survey mergeable staircase runs: consecutive solid platforms where the gap
## is within jump range (so currently a "hop") and the height step is a
## reasonable single stair riser. These are exactly the candidates for
## becoming continuous walkable ground instead of a jump.
const GAP_MAX := 200.0
const RISER_MAX := 120.0
func _initialize() -> void:
	var total_plats := 0
	var total_mergeable := 0
	for n in range(1, LevelData.TOTAL_LEVELS + 1):
		var lv := LevelData.get_level(n)
		var ps: Array = []
		for p in lv.platforms:
			var nm := String(p.name)
			if nm.contains("Wall") or nm.contains("Decoy") or nm == "Ground":
				continue
			if p.kind != "solid":
				continue
			ps.append(p)
		ps.sort_custom(func(a, b): return a.position.x < b.position.x)
		total_plats += ps.size()
		var runs := 0
		var run_len := 0
		var i := 0
		while i + 1 < ps.size():
			var a = ps[i]; var b = ps[i+1]
			var gap: float = (b.position.x - b.size.x*0.5) - (a.position.x + a.size.x*0.5)
			var riser: float = absf(a.position.y - b.position.y)
			if gap > 0.0 and gap <= GAP_MAX and riser <= RISER_MAX:
				run_len += 1
				total_mergeable += 1
			i += 1
		print("L%d: %d solid platforms, %d mergeable gaps" % [n, ps.size(), run_len])
	print("TOTAL: %d platforms, %d mergeable gaps (%.0f%% of platforms touch a mergeable gap)"
		% [total_plats, total_mergeable, 100.0 * total_mergeable / total_plats])
	quit(0)
