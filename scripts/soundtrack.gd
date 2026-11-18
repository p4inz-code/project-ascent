# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
extends Node
## The game's music, kept alive across scenes (autoload `Soundtrack`).
##
## Before 0.19.0 the music lived in the per-level audio node, so every death-free level reload restarted the loop.
## Now one track plays per place (title, story, each act, boss chase, endless, ending) and changing places
## crossfades. Asking for the track that is already playing does nothing, so reloading a level never restarts it.
## The tracks are made by tools/music_engine.py; every one loops seamlessly.
##
## Web autoplay safety: nothing starts before the first real input in the browser build. Desktop starts at once.

const DIR := "res://audio/music/"
const ACT_TRACKS: Array[String] = ["cinder", "scrapyard", "freezer", "storm", "forge", "underworks", "rift", "core"]
const ALL_TRACKS: Array[String] = ["title", "story", "cinder", "scrapyard", "freezer", "storm", "forge",
		"underworks", "rift", "core", "boss", "endless", "ending"]
const DEFAULT_FADE := 1.2

var current: String = ""        # the track that is wanted (it may still be waiting for the first input)
var _unlocked: bool = false
var _players: Array[AudioStreamPlayer] = []
var _front: int = 0
var _tween: Tween = null
var _streams: Dictionary = {}


## Which track belongs to a place. Levels run 1-40, five per act; endless and a boss chase override the act.
static func track_for_level(level: int, endless: bool = false, boss_chase: bool = false) -> String:
	if boss_chase:
		return "boss"
	if endless:
		return "endless"
	return ACT_TRACKS[clampi((level - 1) / 5, 0, ACT_TRACKS.size() - 1)]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_unlocked = not OS.has_feature("web")


func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		unlock()


## The first real input (the level calls this too). Starts the track that was asked for while locked.
func unlock() -> void:
	if _unlocked and _players[_front].playing:
		return
	_unlocked = true
	if current != "":
		var want := current
		current = ""
		play(want, 0.4)


func is_playing(track: String = "") -> bool:
	var p := _players[_front]
	return p.playing and (track == "" or track == current)


## Play a track, crossfading from the current one. Does nothing if it is already the one playing.
func play(track: String, fade: float = DEFAULT_FADE) -> void:
	if track == current and (_players[_front].playing or not _unlocked):
		return
	if not track in ALL_TRACKS:
		push_warning("Soundtrack: unknown track '%s'" % track)
		return
	current = track
	if not _unlocked:
		return
	var stream := _stream(track)
	if stream == null:
		return
	var old := _players[_front]
	_front = 1 - _front
	var fresh := _players[_front]
	fresh.stream = stream
	fresh.pitch_scale = 1.0
	fresh.volume_db = -80.0 if fade > 0.0 else 0.0
	fresh.play()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if fade <= 0.0:
		old.stop()
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(fresh, "volume_db", 0.0, fade)
	if old.playing:
		_tween.tween_property(old, "volume_db", -80.0, fade)
		_tween.chain().tween_callback(old.stop)


## Fade out and stop (a level's silence, quitting to the title).
func stop(fade: float = 0.8) -> void:
	current = ""
	var p := _players[_front]
	if not p.playing:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if fade <= 0.0:
		p.stop()
		return
	_tween = create_tween()
	_tween.tween_property(p, "volume_db", -80.0, fade)
	_tween.tween_callback(p.stop)


func _stream(track: String) -> AudioStream:
	if _streams.has(track):
		return _streams[track]
	var s := load(DIR + track + ".ogg") as AudioStream
	if s is AudioStreamOggVorbis:
		s.loop = true
		s.loop_offset = 0.0
	_streams[track] = s
	return s
