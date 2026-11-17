# Copyright (c) 2026 Atharva Patil, P4inz Interactive Labs. See LICENSE and ADDITIONAL_TERMS.md.
# SPDX-License-Identifier: GPL-3.0-only
class_name PageShell
extends RefCounted
## The one page design every menu page shares: a header (pixel icon, title in the accent colour, a one-line
## subtitle), thin pixel rules between header, body and footer, and the footer key hints. Pages used to each
## invent their own title (spaced letters, plain, centred, with or without an icon) at different widths.


## Header row: icon, then title over subtitle. Returns the HBox so a page can add a control on the right.
static func header(icon: Texture2D, title: String, subtitle: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "PageHeader"
	row.add_theme_constant_override("separation", 18)
	if icon != null:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tr.custom_minimum_size = Vector2(64, 64)
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tr)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	var t := Label.new()
	t.name = "Title"
	t.text = title
	t.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE)
	t.add_theme_color_override("font_color", UITheme.accent)
	text.add_child(t)
	if subtitle != "":
		var s := Label.new()
		s.name = "Subtitle"
		s.text = subtitle
		s.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
		s.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		text.add_child(s)
	return row


## A thin pixel rule.
static func rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = UITheme.LINE
	r.custom_minimum_size = Vector2(0, UITheme.PX)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The footer hint line (keys), dim small type.
static func hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
	l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	return l
