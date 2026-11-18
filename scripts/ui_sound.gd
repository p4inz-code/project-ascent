# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
extends Node
## Menu sounds for every button in the game (autoload `UiSound`).
##
## Any button that enters the tree gets a soft tick when it is highlighted (mouse or keyboard/pad focus), a
## rising chime when it is chosen, and a falling one when it is a back/close button. Wired by watching
## `node_added`, so every menu, page and pause screen has it without each one asking. Plays on the UI bus, so
## Settings > Audio > Menu sounds controls it, and works with or without a level running.

const SOUNDS := {"hover": "res://audio/sfx/hover.wav", "select": "res://audio/sfx/select.wav", "back": "res://audio/sfx/back.wav"}
const BACK_WORDS := ["BACK", "CLOSE", "CANCEL", "LATER", "NO", "EXIT"]
const HOVER_GAP_MS := 60

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_hover_ms: int = -1000
var wired_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioFx.ensure_buses()
	for k in SOUNDS:
		_streams[k] = load(SOUNDS[k])
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = AudioFx.UI_BUS
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)


static func is_back_button(text: String) -> bool:
	var t := text.strip_edges().to_upper()
	for w in BACK_WORDS:
		if t == w or t.begins_with(w + " ") or t.ends_with(" " + w):
			return true
	return false


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("ui_sound"):
		wire(node)


func wire(button: BaseButton) -> void:
	button.set_meta("ui_sound", true)
	wired_count += 1
	button.mouse_entered.connect(_hover.bind(button))
	button.focus_entered.connect(_hover.bind(button))
	button.pressed.connect(_chosen.bind(button))


func _hover(button: BaseButton) -> void:
	if button.disabled:
		return
	var now := Time.get_ticks_msec()
	if now - _last_hover_ms < HOVER_GAP_MS:
		return
	_last_hover_ms = now
	_play("hover", 0.0, 1.0)


func _chosen(button: BaseButton) -> void:
	var text: String = String(button.get("text")) if button.get("text") != null else ""
	_play("back" if is_back_button(text) else "select", 0.0, 1.0)


func _play(id: String, volume_db: float, pitch: float) -> void:
	var s: AudioStream = _streams.get(id)
	if s == null or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
