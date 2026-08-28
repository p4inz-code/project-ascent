extends "res://tests/test_level.gd"
## Frame-cost and node-count probe. Plays the autopilot route in a real window
## and reports per-frame script/render cost percentiles plus node counts at the
## start and end of the run.
##
## Two things this exists to catch, both of which the Performance section of
## docs/ARCHITECTURE.md asserts and neither of which is visible in a screenshot:
##
## 1. The presentation layer (parallax backdrop, star field, vignette shader,
##    HUD, dash trail) must not have moved the frame cost meaningfully. It looks
##    expensive; the claim is that it is not.
## 2. Node count must be FLAT across a run. The dash trail uses a pre-allocated
##    pool precisely so that nothing spawns per frame, and "no per-frame
##    spawning" is easy to regress silently the moment someone writes
##    `add_child()` in a feedback path.
##
## Needs a real window — the headless server does not render, so render-side
## monitors would all read zero. Prints numbers; exits non-zero only if the
## autopilot fails or the node count grows.

const FRAME_BUDGET := 700
const WARMUP_FRAMES := 30

var _goals := [0]
var _finished := false
var _run_frames := 0


func _suite_name() -> String:
	return "probe_perf"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_check("running with a real display server (drop --headless)", false)
		return

	var body: RectangleShape2D = _player.get_node("CollisionShape2D").shape
	_body = body.size
	_main.level_completed.connect(func() -> void: _goals[0] += 1)

	var nodes_before := _count_nodes(root)
	_play()

	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var frame_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var peak_nodes := nodes_before
	var frame := 0
	var last_usec := Time.get_ticks_usec()
	while not _finished and frame < FRAME_BUDGET:
		await RenderingServer.frame_post_draw
		frame += 1
		var now := Time.get_ticks_usec()
		if frame > WARMUP_FRAMES:
			frame_ms.append(float(now - last_usec) / 1000.0)
			process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			physics_ms.append(
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			draw_calls.append(
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			peak_nodes = maxi(peak_nodes, _count_nodes(root))
		last_usec = now

	var nodes_after := _count_nodes(root)

	_check("autopilot reached the goal (%s)" % (
		"%d frames" % _run_frames if _run_frames > 0 else "NEVER FINISHED"),
		_run_frames > 0)
	_check("sampled enough frames (%d)" % frame_ms.size(), frame_ms.size() > 60)

	print("[probe_perf] samples=%d" % frame_ms.size())
	# TIME_PROCESS / TIME_PHYSICS_PROCESS are the engine's whole-frame monitors,
	# not script-only timings, and the process one is vsync-bound. The number that
	# actually reflects the presentation layer's cost is the draw-call count.
	_report("engine process frame", process_ms, "ms")
	_report("engine physics frame", physics_ms, "ms")
	_report("wall frame time (vsync-locked)", frame_ms, "ms")
	_report("draw calls", draw_calls, "")
	print("[probe_perf] nodes: start=%d peak=%d end=%d" % [
		nodes_before, peak_nodes, nodes_after])

	# The trail pool is allocated in _ready(), so by the time the run starts the
	# count is already final. Any growth from here is a per-frame spawn.
	_check("node count does not grow during play (%d -> %d)"
		% [nodes_before, nodes_after], nodes_after <= nodes_before)
	_check("node count does not spike mid-run (peak %d <= start %d)"
		% [peak_nodes, nodes_before], peak_nodes <= nodes_before)


func _play() -> void:
	_run_frames = await _autopilot(-200.0, _goals)
	_finished = true


func _report(label: String, samples: Array[float], unit: String) -> void:
	if samples.is_empty():
		print("[probe_perf] %s: no samples" % label)
		return
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	var avg := total / float(sorted.size())
	print("[probe_perf] %s: avg=%.3f%s median=%.3f%s p95=%.3f%s worst=%.3f%s" % [
		label, avg, unit,
		sorted[sorted.size() / 2], unit,
		sorted[int(float(sorted.size()) * 0.95)], unit,
		sorted[sorted.size() - 1], unit,
	])


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
