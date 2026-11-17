extends SceneTree
## Probe: for platform steps (gap, dy), how many jump-timing frames land the next platform.
func _initialize() -> void:
	for dy in [66.0, 76.0, 84.0]:
		var row := "dy %d: " % int(dy)
		for gap in [90.0, 160.0, 190.0, 210.0, 230.0, 250.0]:
			row += "g%d=%d " % [int(gap), window(gap, dy)]
		print(row)
	quit()

func window(gap: float, dy: float) -> int:
	var ok := 0
	for off in range(-14, 10):
		if land(gap, dy, off):
			ok += 1
	return ok

## off = frames after the feet pass the edge when jump is pressed (negative = before the edge).
func land(gap: float, dy: float, off: int) -> bool:
	var w := MachineWorld.new()
	var a := Rect2(0, 0, 220, 24)
	var b := Rect2(220 + gap, -dy, 220, 24)
	w.add_solid(a); w.add_solid(b)
	w.finalize()
	var s := MachineSim.new(w, Vector2(60, -26.0))
	var edge := 220.0
	var jumped := false
	var f_after := -999
	for i in 400:
		var jp := false
		var x := s.pos.x
		if not jumped and x >= edge + float(off) * 5.3:
			jp = true; jumped = true; f_after = 0
		var hold := jumped and f_after < 40
		s.step(1.0, jp, hold)
		if jumped: f_after += 1
		if s.dead: return false
		if jumped and s.on_floor and s.pos.y < -dy * 0.5 and s.pos.x > b.position.x and s.pos.x < b.end.x:
			return true
		if jumped and s.pos.y > 300: return false
	return false
