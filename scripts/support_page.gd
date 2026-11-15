# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name SupportPage
extends CanvasLayer
## CONTRIBUTE TO DEVELOPMENT: a small page with the pixel heart and the two donation links. The game is
## free and GPL-3.0; nothing is unlocked by donating. Opened from the main page and the About page.

signal closed

var _done: Button


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
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var heart := TextureRect.new()
	heart.name = "Heart"
	heart.texture = PixelHeart.texture(8)
	heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	heart.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	heart.custom_minimum_size = Vector2(0, PixelHeart.height() * 8 + 8)
	col.add_child(heart)
	var title := Label.new()
	title.text = "CONTRIBUTE TO DEVELOPMENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", UITheme.accent)
	col.add_child(title)
	var body := Label.new()
	body.text = "Project Ascent is free and open source (GPL-3.0). Nothing is locked behind a donation. If it ate an evening or two of your life and you want more, a coffee buys the dev more evenings for the next update."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", UITheme.SIZE_BODY)
	col.add_child(body)
	col.add_child(_link_button("SupportBmc", "BUY ME A COFFEE", AboutPage.SUPPORT_BMC))
	col.add_child(_link_button("SupportUpi", "UPI (INDIA)", AboutPage.SUPPORT_UPI))
	_done = Button.new()
	_done.text = "BACK"
	_done.custom_minimum_size = Vector2(0, 48)
	_done.pressed.connect(close)
	col.add_child(_done)
	_done.call_deferred("grab_focus")


func _link_button(node_name: String, text: String, url: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.icon = PixelHeart.texture(2)
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(func() -> void: OS.shell_open(url))
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	closed.emit()
	queue_free()
