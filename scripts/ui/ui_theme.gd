class_name UITheme
extends RefCounted

## Vzhled celeho UI: paleta, typograficka skala a tovarny na widgety.
##
## Klicova zmena Faze 6: krome tovaren se tu staví i skutecny `Theme`
## (`build_theme()`), ktery se priradi korenovemu Control. Godot ho pak
## propaguje do celeho stromu, takze se nastyluji i kontroly, ktere si nikdo
## rucne neupravuje — Button, ProgressBar, ScrollBar, LineEdit. Presne tohle
## drív chybelo: `button()` nenastavovalo nic a kazde tlacitko ve hre melo
## vychozi Godot skin, coz byl hlavni duvod, proc hra vypadala nedodelane.
##
## Vytvarny smer: rozvrzeni moderniho strategickeho HUD (jasna hierarchie,
## dech, citelna cisla) v zapadnim materialu — tonovane drevo a kuze, mosaz
## na akcenty, pergamen na text.

# --- Fonty -------------------------------------------------------------------

const DISPLAY_FONT_PATH := "res://assets/fonts/Rye-Regular.ttf"
const BODY_FONT_PATH := "res://assets/fonts/Bitter.ttf"

## Bitter je variabilni. Osa se MUSI adresovat celociselnym tagem — retezcovy
## klic {"wght": 700} Godot tise ignoruje a vykresli zakladni instanci, coz je
## u Bitteru Thin. Hlida to scripts/dev/font_check.gd.
const WEIGHT_LIGHT := 300
const WEIGHT_REGULAR := 400
const WEIGHT_MEDIUM := 500
const WEIGHT_SEMIBOLD := 600
const WEIGHT_BOLD := 700

static var _display_font: FontFile
static var _body_font: FontFile
static var _weight_cache: Dictionary = {}


## Rye — VYHRADNE logotyp "IRON DUST".
##
## Rye nema 8 z 15 ceskych pismen s diakritikou (Č Ď Ě Ň Š Ť Ů Ž), velka ani
## mala — overeno dotazem na has_char(). Na cesky nadpis se tedy nehodi:
## "ZAČÁTEČNÍK" se vykreslil s Č z nahradniho fontu v jine velikosti. Proto
## nese westernovou identitu jen logo (ktere diakritiku nema) a vsechny ostatni
## nadpisy jdou pres heading() v tezkem rezu Bitteru.
##
## Bitter je nastaveny jako fallback, aby pripadne budouci pouziti degradovalo
## do pribuzneho slabu misto do vychoziho Godot fontu.
static func display_font() -> FontFile:
	if _display_font == null:
		_display_font = load(DISPLAY_FONT_PATH)
		if _body_font == null:
			_body_font = load(BODY_FONT_PATH)
		_display_font.fallbacks = [_body_font]
	return _display_font


## Bitter v pozadovane vaze. Vysledky se cachuji — FontVariation je resource
## a stavet ho na kazdy popisek zvlast by bylo zbytecne drahé.
static func body_font(weight: int = WEIGHT_REGULAR) -> Font:
	if _weight_cache.has(weight):
		return _weight_cache[weight]

	if _body_font == null:
		_body_font = load(BODY_FONT_PATH)

	var variation := FontVariation.new()
	variation.base_font = _body_font
	variation.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("weight"): weight,
	}
	_weight_cache[weight] = variation
	return variation


# --- Paleta ------------------------------------------------------------------

## Podklady: od nejhlubsiho stinu po zvednuty povrch.
const INK := Color(0.055, 0.047, 0.042)
const LEATHER := Color(0.098, 0.082, 0.070)
const LEATHER_RAISED := Color(0.137, 0.115, 0.098)
const LEATHER_SUNKEN := Color(0.070, 0.059, 0.051)

## Mosaz — akcent doby. Ohraniceni, nadpisy, aktivni stavy.
const BRASS := Color(0.804, 0.639, 0.325)
const BRASS_BRIGHT := Color(0.925, 0.788, 0.478)
const BRASS_DEEP := Color(0.478, 0.365, 0.169)

## Pergamen — text.
const PARCHMENT := Color(0.949, 0.906, 0.827)
const PARCHMENT_DIM := Color(0.663, 0.612, 0.529)
const PARCHMENT_FAINT := Color(0.435, 0.400, 0.353)

## Vyznamove barvy.
const POSITIVE := Color(0.478, 0.729, 0.427)
const NEGATIVE := Color(0.816, 0.361, 0.302)
const WARNING := Color(0.878, 0.639, 0.263)
## Harlan-Voss. Stejny odstin nosi i cerveny obrys uzemi na mape.
const ENEMY := Color(0.788, 0.267, 0.224)

# Zpetne kompatibilni aliasy — drzi pri zivote UI z Fazi 2-5, nez se prepise.
const PANEL_BG := LEATHER
const OVERLAY_BG := INK
const CARD_BG := LEATHER_RAISED
const CARD_BG_ACTIVE := Color(0.216, 0.169, 0.078)
const CARD_BG_MUTED := LEATHER_SUNKEN
const GOLD := BRASS
const DIM := PARCHMENT_DIM
const MUTED_BORDER := Color(0.3, 0.28, 0.25, 0.6)

# --- Typograficka skala ------------------------------------------------------

## Pojmenovane stupne misto magickych cisel roztrousenych po call sites.
const SIZE_DISPLAY := 34
const SIZE_TITLE := 24
const SIZE_HEADING := 17
const SIZE_NUMBER := 17
const SIZE_BODY := 15
const SIZE_SMALL := 13
const SIZE_TINY := 11

# --- Rozmery -----------------------------------------------------------------

const RADIUS := 3
const BORDER := 1
const BUTTON_HEIGHT := 40
const GAP_TIGHT := 4
const GAP := 8
const GAP_LOOSE := 14
const PAD := 12


# --- Theme -------------------------------------------------------------------

## Postavi kompletni Theme. Priradit jednou na korenovy Control — Godot ho
## propaguje do celeho podstromu, vcetne kontrol, ktere si nikdo neupravuje.
static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = body_font(WEIGHT_REGULAR)
	theme.default_font_size = SIZE_BODY

	_style_button(theme)
	_style_panels(theme)
	_style_progress(theme)
	_style_scrollbars(theme)
	_style_separators(theme)
	_style_misc(theme)
	return theme


static func _style_button(theme: Theme) -> void:
	# Spodni okraj je o pixel silnejsi — plech tim dostane vahu a tlacitko
	# prestane pusobit jako plocha nalepka.
	var normal := _flat(LEATHER_RAISED, BRASS_DEEP)
	normal.border_width_bottom = BORDER + 1
	normal.content_margin_left = PAD + 4
	normal.content_margin_right = PAD + 4
	normal.content_margin_top = GAP
	normal.content_margin_bottom = GAP

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.180, 0.150, 0.118)
	hover.border_color = BRASS

	# Stisknute se propada: tmavsi vypln a vaha okraje nahore misto dole.
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = LEATHER_SUNKEN
	pressed.border_color = BRASS_BRIGHT
	pressed.border_width_bottom = BORDER
	pressed.border_width_top = BORDER + 1

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.086, 0.075, 0.067)
	disabled.border_color = Color(0.239, 0.216, 0.188)
	disabled.border_width_bottom = BORDER

	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = BRASS_BRIGHT
	focus.set_border_width_all(BORDER + 1)

	for entry in [["normal", normal], ["hover", hover], ["pressed", pressed],
			["disabled", disabled], ["focus", focus]]:
		theme.set_stylebox(entry[0], "Button", entry[1])

	theme.set_font("font", "Button", body_font(WEIGHT_SEMIBOLD))
	theme.set_font_size("font_size", "Button", SIZE_SMALL)
	theme.set_color("font_color", "Button", PARCHMENT)
	theme.set_color("font_hover_color", "Button", BRASS_BRIGHT)
	theme.set_color("font_pressed_color", "Button", BRASS_BRIGHT)
	theme.set_color("font_focus_color", "Button", PARCHMENT)
	theme.set_color("font_disabled_color", "Button", PARCHMENT_FAINT)


static func _style_panels(theme: Theme) -> void:
	var panel := _flat(LEATHER, BRASS_DEEP)
	panel.set_content_margin_all(PAD)
	# Stin oddeli panel od 3D sceny pod nim; bez nej UI na mape "plave".
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 6
	theme.set_stylebox("panel", "PanelContainer", panel)

	var plain := _flat(LEATHER, BRASS_DEEP)
	plain.set_content_margin_all(0)
	theme.set_stylebox("panel", "Panel", plain)


static func _style_progress(theme: Theme) -> void:
	var background := _flat(LEATHER_SUNKEN, Color(0.239, 0.216, 0.188))
	background.set_content_margin_all(0)
	theme.set_stylebox("background", "ProgressBar", background)

	var fill := _flat(BRASS, BRASS_BRIGHT)
	fill.set_content_margin_all(0)
	theme.set_stylebox("fill", "ProgressBar", fill)

	theme.set_font("font", "ProgressBar", body_font(WEIGHT_SEMIBOLD))
	theme.set_font_size("font_size", "ProgressBar", SIZE_TINY)
	theme.set_color("font_color", "ProgressBar", PARCHMENT)


## Etapa 2 postavi vodorovny pas stavebnich karet, takze scrollbary uz nesmi
## byt vychozi sedive.
static func _style_scrollbars(theme: Theme) -> void:
	for axis in ["HScrollBar", "VScrollBar"]:
		var track := _flat(LEATHER_SUNKEN, Color(0, 0, 0, 0))
		track.set_content_margin_all(0)
		theme.set_stylebox("scroll", axis, track)

		var grabber := _flat(BRASS_DEEP, Color(0, 0, 0, 0))
		grabber.set_content_margin_all(0)
		theme.set_stylebox("grabber", axis, grabber)

		var grabber_hover := _flat(BRASS, Color(0, 0, 0, 0))
		grabber_hover.set_content_margin_all(0)
		theme.set_stylebox("grabber_highlight", axis, grabber_hover)

		var grabber_pressed := _flat(BRASS_BRIGHT, Color(0, 0, 0, 0))
		grabber_pressed.set_content_margin_all(0)
		theme.set_stylebox("grabber_pressed", axis, grabber_pressed)

	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())


static func _style_separators(theme: Theme) -> void:
	for axis in ["HSeparator", "VSeparator"]:
		var line := StyleBoxLine.new()
		line.color = BRASS_DEEP
		line.thickness = 1
		line.vertical = axis == "VSeparator"
		theme.set_stylebox("separator", axis, line)
		theme.set_constant("separation", axis, GAP)


static func _style_misc(theme: Theme) -> void:
	theme.set_color("font_color", "Label", PARCHMENT)

	var field := _flat(LEATHER_SUNKEN, BRASS_DEEP)
	field.set_content_margin_all(GAP)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_color("font_color", "LineEdit", PARCHMENT)
	theme.set_color("caret_color", "LineEdit", BRASS)

	var tooltip := _flat(INK, BRASS_DEEP)
	tooltip.set_content_margin_all(GAP)
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_color("font_color", "TooltipLabel", PARCHMENT)
	theme.set_font_size("font_size", "TooltipLabel", SIZE_SMALL)


static func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(BORDER)
	style.set_corner_radius_all(RADIUS)
	return style


# --- Stylebox tovarny (pouziva stavajici UI) ---------------------------------

static func panel_style(bg: Color = PANEL_BG, border: Color = BRASS,
		border_alpha: float = 0.55, margin: int = PAD) -> StyleBoxFlat:
	var style := _flat(bg, Color(border.r, border.g, border.b, border_alpha))
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 5
	return style


static func card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := _flat(bg, border)
	style.set_content_margin_all(GAP)
	return style


# --- Widget tovarny ----------------------------------------------------------

static func label(text: String, size: int = SIZE_BODY, color: Color = PARCHMENT,
		weight: int = WEIGHT_REGULAR) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", body_font(weight))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func wrapped_label(text: String, size: int = SIZE_SMALL,
		color: Color = PARCHMENT, width: float = 300.0,
		weight: int = WEIGHT_REGULAR) -> Label:
	var node := label(text, size, color, weight)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(width, 0)
	return node


## Nadpis. Tezky rez Bitteru s rozpalem misto Rye — Rye nekryje ceskou
## diakritiku (viz display_font()). Rozpal a vaha z nej udelaji dostatecne
## vyrazny display styl a cestina zustane spravne.
static func heading(text: String, size: int = SIZE_HEADING,
		color: Color = BRASS) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", body_font(WEIGHT_BOLD))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	# Rozpal roste s velikosti; u malych popisku by sirsi mezery skodily.
	node.add_theme_constant_override("font_spacing_glyph", 1 if size < 22 else 2)
	return node


## Logotyp hry. Jedine misto, kde se pouziva Rye — "IRON DUST" diakritiku nema,
## takze tu westernovy font funguje bez vyhrad.
static func logotype(size: int = SIZE_DISPLAY, color: Color = BRASS) -> Label:
	var node := Label.new()
	node.text = "IRON DUST"
	node.add_theme_font_override("font", display_font())
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


## Cislo v zahlavi — polotucny rez, aby hodnoty vystoupily nad popisky.
static func number(text: String, size: int = SIZE_NUMBER,
		color: Color = PARCHMENT) -> Label:
	var node := label(text, size, color, WEIGHT_SEMIBOLD)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return node


static func button(text: String, min_size: Vector2 = Vector2.ZERO) -> Button:
	var node := Button.new()
	node.text = text
	if min_size == Vector2.ZERO:
		node.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	else:
		node.custom_minimum_size = min_size
	return node


static func panel(bg: Color = PANEL_BG, margin: int = PAD) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", panel_style(bg, BRASS, 0.55, margin))
	return node


static func column(separation: int = 6) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func row(separation: int = GAP) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


# --- Vyznamove barvy ---------------------------------------------------------

static func message_color(type: String) -> Color:
	match type:
		"success":
			return POSITIVE
		"warning":
			return NEGATIVE
		"production":
			return BRASS
		_:
			return PARCHMENT


static func amount_color(value: int) -> Color:
	if value > 0:
		return POSITIVE
	if value < 0:
		return NEGATIVE
	return PARCHMENT_DIM
