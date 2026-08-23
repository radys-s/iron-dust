class_name UITheme
extends RefCounted

## Shared palette and widget factories for the Iron Dust HUD.
##
## The interface is built in code rather than in .tscn files so a panel's whole
## layout stays readable in one place; this module keeps the styling from being
## copy-pasted into every one of them.

const PANEL_BG := Color(0.09, 0.075, 0.06, 0.92)
const OVERLAY_BG := Color(0.07, 0.06, 0.05, 0.97)
const CARD_BG := Color(0.13, 0.11, 0.09, 0.95)
const CARD_BG_ACTIVE := Color(0.24, 0.19, 0.08, 0.95)
const CARD_BG_MUTED := Color(0.10, 0.09, 0.08, 0.9)

const GOLD := Color(0.83, 0.66, 0.33)
const PARCHMENT := Color(0.95, 0.89, 0.74)
const DIM := Color(0.62, 0.55, 0.44)
const POSITIVE := Color(0.44, 0.79, 0.47)
const NEGATIVE := Color(0.85, 0.36, 0.30)
const MUTED_BORDER := Color(0.3, 0.28, 0.25, 0.6)


static func panel_style(bg: Color = PANEL_BG, border: Color = GOLD,
		border_alpha: float = 0.55, margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(border.r, border.g, border.b, border_alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(margin)
	return style


static func card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	return style


static func label(text: String, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func wrapped_label(text: String, size: int, color: Color, width: float) -> Label:
	var node := label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(width, 0)
	return node


static func heading(text: String, size: int = 19) -> Label:
	return label(text, size, GOLD)


static func button(text: String, min_size: Vector2 = Vector2.ZERO) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = min_size
	return node


static func panel(bg: Color = PANEL_BG, margin: int = 12) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", panel_style(bg, GOLD, 0.55, margin))
	return node


static func column(separation: int = 6) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func row(separation: int = 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## Colour of a notification / log line by its type tag.
static func message_color(type: String) -> Color:
	match type:
		"success":
			return POSITIVE
		"warning":
			return NEGATIVE
		"production":
			return GOLD
	return PARCHMENT


static func amount_color(value: int) -> Color:
	if value > 0:
		return POSITIVE
	if value < 0:
		return NEGATIVE
	return DIM
