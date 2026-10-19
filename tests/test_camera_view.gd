extends SceneTree
## The camera view: zoom presets, follow speed and hold-to-peek, and the fairness rules that go
## with them (Wide and peek are off in boss chases; peek never fights the screen shake).

var _failures: int = 0
var _gs: Node


func _initialize() -> void:
	_boot()


func _boot() -> void:
	await physics_frame
	_gs = root.get_node("GameSettings")
	_gs.reset_settings()
	await _normal_level()
	await _pressure_level()
	print("[test_camera_view] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _step(n: int) -> void:
	for _i in n:
		await physics_frame
	await process_frame


func _load(level: int) -> Node:
	var scene := (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	scene.set("level_number", level)
	root.add_child(scene)
	await _step(12)
	return scene


func _normal_level() -> void:
	var scene := await _load(1)
	var player: Player = scene.get_node("Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var view: CameraView = player.get_node_or_null("CameraView")
	_check("the player has a camera view", view != null and cam != null)
	_check("level 1 is not a pressure level", not view.pressure_level())
	await _step(60)
	_check("DEFAULT zoom is 1.0 (%.2f)" % cam.zoom.x, is_equal_approx(cam.zoom.x, 1.0))
	for pair in [[0, 1.2], [2, 0.8], [1, 1.0]]:
		_gs.set_reg("cam_zoom", pair[0])
		await _step(120)
		_check("%s zoom settles at %.2f (%.3f)" % [CameraView.ZOOM_NAMES[pair[0]], pair[1], cam.zoom.x], absf(cam.zoom.x - float(pair[1])) < 0.02)
	_check("close shows less, wide shows more", CameraView.ZOOMS[0] > CameraView.ZOOMS[1] and CameraView.ZOOMS[2] < CameraView.ZOOMS[1])

	# Follow speed.
	_gs.set_reg("cam_follow", 12.0)
	await _step(5)
	_check("the follow speed setting reaches the camera", is_equal_approx(cam.position_smoothing_speed, 12.0))
	_gs.set_reg("cam_follow", 8.0)

	# Peek.
	_check("at rest the view is not offset", view.peek_offset == Vector2.ZERO and cam.offset == Vector2.ZERO)
	Input.action_press("look_up", 1.0)
	await _step(90)
	_check("holding LOOK UP raises the view (%.0f)" % view.peek_offset.y, view.peek_offset.y < -250.0 and absf(view.peek_offset.x) < 1.0)
	_check("the camera really moved by it (%.0f)" % cam.offset.y, absf(cam.offset.y - view.peek_offset.y) < 1.0)
	Input.action_release("look_up")
	await _step(150)
	_check("letting go snaps the view back", view.peek_offset == Vector2.ZERO and cam.offset == Vector2.ZERO)
	Input.action_press("look_right", 1.0)
	await _step(90)
	_check("LOOK RIGHT looks ahead (%.0f)" % view.peek_offset.x, view.peek_offset.x > 300.0)
	# The shake rides on top of the peek and the peek survives it.
	var shake: CameraShake = player.get_node("CameraShake")
	shake.add_trauma(1.0)
	await _step(4)
	var shaken := cam.offset
	_check("a shake adds to the peek, it does not replace it", shaken != view.peek_offset)
	await _step(200)
	_check("when the shake ends the camera rests on the peek", cam.offset.distance_to(view.peek_offset) < 1.0)
	Input.action_release("look_right")
	await _step(150)
	_gs.set_reg("cam_peek", false)
	Input.action_press("look_up", 1.0)
	await _step(60)
	_check("with peek switched off, holding look does nothing", view.peek_offset == Vector2.ZERO)
	Input.action_release("look_up")
	_gs.reset_settings()
	scene.queue_free()
	await _step(3)


func _pressure_level() -> void:
	# Level 10 is a boss level (rising flood chase).
	var scene := await _load(10)
	var player: Player = scene.get_node("Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var view: CameraView = player.get_node("CameraView")
	_check("level 10 is a pressure level", view.pressure_level())
	_gs.set_reg("cam_zoom", 2)
	await _step(150)
	_check("WIDE falls back to DEFAULT in a boss chase (%.2f)" % cam.zoom.x, absf(cam.zoom.x - 1.0) < 0.02)
	_gs.set_reg("cam_zoom", 0)
	await _step(150)
	_check("CLOSE still applies in a boss chase (%.2f)" % cam.zoom.x, absf(cam.zoom.x - 1.2) < 0.02)
	Input.action_press("look_up", 1.0)
	await _step(90)
	_check("peek is off in a boss chase", view.peek_offset == Vector2.ZERO and view.peek_input() == Vector2.ZERO)
	Input.action_release("look_up")
	_gs.reset_settings()
	scene.queue_free()
	await _step(3)
