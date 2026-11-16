# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name StudioPage
extends CanvasLayer
## MORE FROM P4INZ: the studio's other projects as cards, read from res://data/studio_projects.json so the owner
## can choose and edit the list without touching code. Each card opens its link in the browser.

signal closed

const DATA_PATH := "res://data/studio_projects.json"

var _done: Button


static func load_projects() -> Array:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary) or not (parsed.get("projects") is Array):
		return []
	var out: Array = []
	for p in parsed["projects"]:
		if p is Dictionary and String(p.get("name", "")) != "":
			out.append(p)
	return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 245
	UITheme.refresh_accent(get_node_or_null("/root/GameSettings"))
	add_child(PixelBackdrop.new())
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var frame := PanelContainer.new()
	frame.theme = UITheme.build()
	centre.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	frame.add_child(margin)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(760, 0)
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(head)
	var badge := TextureRect.new()
	badge.texture = PixelIcons.texture(PixelIcons.STUDIO, 5, Color(1.0, 0.7, 0.3))
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(badge)
	var title := Label.new()
	title.text = "MORE FROM P4INZ"
	title.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", UITheme.accent)
	head.add_child(title)

	var first: Button = null
	for p in load_projects():
		var card := _card(p)
		col.add_child(card)
		if first == null:
			first = card
	_done = Button.new()
	_done.name = "Back"
	_done.text = "BACK"
	_done.custom_minimum_size = Vector2(0, 48)
	_done.pressed.connect(close)
	col.add_child(_done)
	(first if first != null else _done).call_deferred("grab_focus")


## A project card: a big button with the name, the status tag and the one-line pitch.
func _card(p: Dictionary) -> Button:
	var b := Button.new()
	b.name = "Project_" + String(p.get("name", "")).to_pascal_case()
	b.custom_minimum_size = Vector2(0, 92)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = false
	var url := String(p.get("url", ""))
	if url != "":
		b.pressed.connect(func() -> void: OS.shell_open(url))
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	b.add_child(pad)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	pad.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	var name_l := Label.new()
	name_l.text = String(p.get("name", ""))
	name_l.add_theme_font_size_override("font_size", UITheme.sz(24))
	top.add_child(name_l)
	var tag := Label.new()
	tag.text = "[ %s ]" % String(p.get("status", ""))
	tag.add_theme_font_size_override("font_size", UITheme.sz(14))
	tag.add_theme_color_override("font_color", UITheme.AMBER)
	tag.visible = String(p.get("status", "")) != ""
	top.add_child(tag)
	var line := Label.new()
	line.text = String(p.get("tagline", ""))
	line.add_theme_font_size_override("font_size", UITheme.sz(15))
	line.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(line)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	closed.emit()
	queue_free()
