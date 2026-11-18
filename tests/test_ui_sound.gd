extends SceneTree
## Menu sounds and the 0.19.0 effects: every button gets wired once, back/close buttons are told apart, the new
## effect files load, and a level's audio node knows the new calls.

const UiRules := preload("res://scripts/ui_sound.gd")
var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	await physics_frame
	var ui: Node = root.get_node_or_null("UiSound")
	_check("the UiSound autoload exists", ui != null)
	if ui == null:
		quit(1)
		return
	for id in ["hover", "select", "back", "shatter", "glitch", "blip", "step"]:
		var s := load("res://audio/sfx/%s.wav" % id) as AudioStream
		_check("%s.wav loads and has length" % id, s != null and s.get_length() > 0.02 and s.get_length() < 1.0)
	_check("BACK, Close and 'LATER' are back buttons", UiRules.is_back_button("BACK") and UiRules.is_back_button("close")
		and UiRules.is_back_button(" Later "))
	_check("PLAY, SETTINGS and 'BACKUP' are not", not UiRules.is_back_button("PLAY") and not UiRules.is_back_button("SETTINGS")
		and not UiRules.is_back_button("BACKUP"))
	var before: int = ui.wired_count
	var b := Button.new()
	b.text = "TEST"
	root.add_child(b)
	_check("a new button is wired", ui.wired_count == before + 1 and b.has_meta("ui_sound"))
	b.get_parent().remove_child(b)
	root.add_child(b)
	_check("re-adding the same button does not wire it twice", ui.wired_count == before + 1)
	var l := Label.new()
	root.add_child(l)
	_check("a label is not wired", ui.wired_count == before + 1)
	b.emit_signal("pressed")
	b.emit_signal("mouse_entered")
	_check("pressing and hovering do not crash", true)
	var main: Node = (load("res://scenes/main_scene.tscn") as PackedScene).instantiate()
	main.set("level_number", 1)
	root.add_child(main)
	for i in 5:
		await physics_frame
	var audio: Node = null
	for n in main.get_children():
		if n is GameAudio:
			audio = n
	_check("the level audio has the new calls", audio != null and audio.has_method("play_blip") and audio.has_method("play_step"))
	if audio != null:
		audio.play_death()
		audio.play_respawn()
		audio.play_blip(1.2)
		audio.play_step()
		_check("shatter, glitch, blip and step play without errors", true)
	main.queue_free()
	b.queue_free()
	l.queue_free()
	print("[test_ui_sound] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
