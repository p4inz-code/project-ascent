class_name GameAudio
extends Node
## Centralized audio for Project Ascent.
##
## Owned by the level (a child of `Main`) so every stream, bus and volume in the
## game lives in one place and is freed with the scene. There are deliberately no
## third-party audio files: each stream is procedurally synthesized by
## `tools/generate_audio.py` (see docs/AUDIO.md for the full provenance record).
##
## Architecture:
## - Three buses: `Master` (exists by default in Godot), `Music`, and `SFX`.
##   Default volumes keep the music comfortably underneath the one-shots so the
##   loop never fights repeated attempts.
## - One looping `AudioStreamPlayer` for the music track.
## - A fixed pool of `AudioStreamPlayer`s for one-shot SFX, reused round-robin.
##   Nothing is spawned per frame, so the "node count stays flat during play"
##   invariant (docs/ARCHITECTURE.md → Performance) is preserved, and there is a
##   dedicated continuous looper for the wall-slide hiss.
## - Web autoplay safety: audio only starts on `unlock_audio()`, which the level
##   controller calls on the first real input. Nothing plays before interaction,
##   so the HTML5 build does not hit a browser autoplay block.
## - Minimal, discoverable keyboard volume control (see docs/SESSION_HANDOFF.md).
##   An on-screen Settings menu is documented as future UX work, not built here.

## Default bus volumes (dB). `Music` starts well under `SFX` so the loop sits
## underneath the effect sounds during fast, noisy traversal.
@export_range(-40.0, 6.0) var master_volume_db: float = 0.0
@export_range(-40.0, 6.0) var music_volume_db: float = -20.0
@export_range(-40.0, 6.0) var sfx_volume_db: float = -8.0

## Volume adjust per key press, in dB.
@export var volume_step_db: float = 2.0
## Clamp the bottom of the volume range so a stray press cannot fully silence
## the game with no way back except the mute toggle.
@export var volume_min_db: float = -34.0
## Largest loudness the volume keys will reach.
@export var volume_max_db: float = 6.0

## How many one-shot `AudioStreamPlayer`s are pooled. Dash + landing can stack, so
## a small pool absorbs overlap without shallow-stealing the most recent sound.
@export var sfx_pool_size: int = 8

const MUSIC_PATH := "res://audio/music/music_loop.ogg"

var _parent_level: Node
var _player: Player
var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_pool: int = 0
var _wall_player: AudioStreamPlayer = null
var _wall_sliding: bool = false
var _streams: Dictionary = {}

var _master_bus: int = 0
var _music_bus: int = 1
var _sfx_bus: int = 2
var _music_started: bool = false
var _muted: bool = false
var _mute_remember_db: float = 0.0


func _ready() -> void:
	_build_buses()
	_parent_level = get_parent()
	_player = (_parent_level as Node).get_node_or_null("Player") as Player
	_load_streams()
	_build_music_player()
	_build_sfx_pool()
	_connect_signals()


## Register the three buses exactly once. Godot ships a `Master` bus; `Music` and
## `SFX` are created as its children if they do not already exist.
func _build_buses() -> void:
	_master_bus = _bus_or_create("Master")
	_music_bus = _bus_or_create("Music")
	_sfx_bus = _bus_or_create("SFX")
	AudioServer.set_bus_volume_db(_master_bus, master_volume_db)
	AudioServer.set_bus_volume_db(_music_bus, music_volume_db)
	AudioServer.set_bus_volume_db(_sfx_bus, sfx_volume_db)


func _bus_or_create(name: String) -> int:
	var idx := AudioServer.get_bus_index(name)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	var new_idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(new_idx, name)
	if new_idx != 0:
		AudioServer.set_bus_send(new_idx, "Master")
	return new_idx


func _load_streams() -> void:
	for id in ["jump", "land", "walljump", "dash", "death", "respawn", "goal",
			"ui", "restart", "wallslide"]:
		_streams[id] = load("res://audio/sfx/%s.wav" % id)


func _build_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	var music: AudioStream = load(MUSIC_PATH) as AudioStream
	if music is AudioStreamOggVorbis:
		music.loop = true
		music.loop_offset = 0.0
	_music_player.stream = music
	add_child(_music_player)


func _build_sfx_pool() -> void:
	for i in sfx_pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	_wall_player = AudioStreamPlayer.new()
	_wall_player.bus = "SFX"
	# The hiss is shipped as a loop-seamless one-shot WAV. Instead of relying on
	# AudioStreamWAV.LOOP_FORWARD (unreliable on some backends), we re-play it on
	# `finished` while the slide is still active, which is the exact same code path
	# the verified one-shot pool uses and loops cleanly because the noise data is
	# seamless by construction.
	_wall_player.stream = _streams["wallslide"]
	_wall_player.finished.connect(_on_wall_finished)
	add_child(_wall_player)


func _connect_signals() -> void:
	if _player != null:
		if _player.has_signal("landed"):
			_player.landed.connect(_on_landed)
		if _player.has_signal("jumped"):
			_player.jumped.connect(_on_jumped)
		if _player.has_signal("wall_jumped"):
			_player.wall_jumped.connect(_on_wall_jumped)
		if _player.has_signal("dashed"):
			_player.dashed.connect(_on_dashed)
		if _player.has_signal("wall_slide_started"):
			_player.wall_slide_started.connect(_on_wall_slide_started)
		if _player.has_signal("wall_slide_ended"):
			_player.wall_slide_ended.connect(_on_wall_slide_ended)
	if _parent_level != null and _parent_level.has_signal("level_completed"):
		_parent_level.level_completed.connect(_on_level_completed)


## Begin the music loop. Called by the level controller on the first real input,
## which is the browser-activation-safe moment on HTML5 and a clean "music starts
## when the run starts" cue natively. Idempotent.
func unlock_audio() -> void:
	if _music_started:
		return
	_music_started = true
	_music_player.play()


## Stop the continuous wall-slide hiss. Called on respawn so a player that died
## mid-slide does not carry the looping hiss into the new life. Music is left
## playing across attempts on purpose.
func stop_wall_slide() -> void:
	_wall_sliding = false
	if _wall_player != null:
		_wall_player.stop()


# --- SFX triggers ------------------------------------------------------------

func _on_landed(fall_speed: float) -> void:
	# Softer landings are quieter; a hard slam is a bigger thud. Clamp the range
	# so extreme falls cap instead of blasting.
	var scaled_db := clampf(fall_speed / 900.0, 0.0, 1.0) * 12.0 - 9.0
	_play("land", scaled_db)


func _on_jumped() -> void:
	_play("jump")


func _on_wall_jumped() -> void:
	_play("walljump")


func _on_dashed() -> void:
	_play("dash")


func _on_wall_slide_started() -> void:
	_wall_sliding = true
	_wall_player.play()


## Re-arm the looping hiss each time the one-shot finishes, as long as the player
## is still sliding. The hermit noise loops silently so there is no audible seam.
func _on_wall_finished() -> void:
	if _wall_sliding:
		_wall_player.play()


func _on_wall_slide_ended() -> void:
	_wall_sliding = false
	_wall_player.stop()


func _on_level_completed() -> void:
	_play("goal")


## Death (fell below the kill plane) and respawn/restart are triggered by the
## level controller, which knows the difference; it calls these directly.
func play_death() -> void:
	_play("death")


func play_respawn() -> void:
	_play("respawn")


func play_restart() -> void:
	_play("restart")


func play_ui() -> void:
	_play("ui")


## Play a one-shot SFX from the pool. Reuses the next free player so overlapping
## or repeated sounds never allocate nodes. `pitch` supports cheap variation.
func _play(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		return
	var player := _sfx_pool[_next_pool]
	_next_pool = (_next_pool + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


# --- Volume control ----------------------------------------------------------

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("audio_mute"):
		_toggle_mute()
		return
	# A subtle blip whenever the controls panel is shown or hidden.
	if Input.is_action_just_pressed("toggle_help"):
		_play("ui")
		return
	# Volume keys step the relevant bus; the master and the two sub-buses are
	# adjustable independently.
	var changed := false
	var master_new := AudioServer.get_bus_volume_db(_master_bus)
	if Input.is_action_just_pressed("audio_master_down"):
		master_new -= volume_step_db
		changed = true
	if Input.is_action_just_pressed("audio_master_up"):
		master_new += volume_step_db
		changed = true
	if changed:
		_set_volume(_master_bus, master_new, "master")
		return
	var music_new := AudioServer.get_bus_volume_db(_music_bus)
	if Input.is_action_just_pressed("audio_music_down"):
		music_new -= volume_step_db
		changed = true
	if Input.is_action_just_pressed("audio_music_up"):
		music_new += volume_step_db
		changed = true
	if changed:
		_set_volume(_music_bus, music_new, "music")
		return
	var sfx_new := AudioServer.get_bus_volume_db(_sfx_bus)
	if Input.is_action_just_pressed("audio_sfx_down"):
		sfx_new -= volume_step_db
		changed = true
	if Input.is_action_just_pressed("audio_sfx_up"):
		sfx_new += volume_step_db
		changed = true
	if changed:
		_set_volume(_sfx_bus, sfx_new, "sfx")


func _set_volume(bus: int, value: float, label: String) -> void:
	var v := clampf(value, volume_min_db, volume_max_db)
	AudioServer.set_bus_volume_db(bus, v)
	_play("ui")
	print("[GameAudio] %s volume %.1f dB" % [label, v])


func _toggle_mute() -> void:
	_muted = not _muted
	if _muted:
		_mute_remember_db = AudioServer.get_bus_volume_db(_master_bus)
		AudioServer.set_bus_mute(_master_bus, true)
	else:
		AudioServer.set_bus_mute(_master_bus, false)
		AudioServer.set_bus_volume_db(_master_bus, _mute_remember_db)
	_play("ui")


## Convenience getters for HUD/tests to read the current bus levels.
func music_db() -> float:
	return AudioServer.get_bus_volume_db(_music_bus)


func sfx_db() -> float:
	return AudioServer.get_bus_volume_db(_sfx_bus)


func master_db() -> float:
	return AudioServer.get_bus_volume_db(_master_bus)
