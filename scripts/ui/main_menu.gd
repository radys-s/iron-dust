extends Control

## Hlavni menu a vyber obtiznosti.
##
## Tok, ktery si Tomas vyslovne prál:
##   - Uplne prvni spusteni: Hrat skoci ROVNOU do Beginner s tutorialem.
##     Kdyz hrac tutorial preskoci, dostane vyber Beginner/Advanced.
##   - Kazde dalsi spusteni: normalni menu, Hrat nabidne
##     Beginner/Advanced/Tutorial.
## Priznak `seen_intro` proto zije v AppConfig (prezije restart, nesouvisi
## se save slotem) a nastavuje se v okamziku, kdy hrac poprve neco zvoli.
##
## Tutorial je zamerne az pod Pokracovat — je dostupny, ale neni to prvni vec,
## kterou hra nabizi.

const GAME_SCENE := "res://scenes/game.tscn"

## Sirka sloupce s nabidkou. Pevna, aby tlacitka drzela svislou linku.
const MENU_WIDTH := 420.0

var _menu_column: VBoxContainer
var _subtitle: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build_theme()

	add_child(MenuBackdrop.new())
	_build_layout()

	if bool(AppConfig.get_value("seen_intro")):
		_show_main()
	else:
		# Prvni spusteni: zadne rozcestnik, rovnou nabidka zacit.
		_show_first_run()


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var column := UITheme.column(0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	# Bez SHRINK_BEGIN by se sloupec roztáhl na celou zbývající šířku a tlačítka
	# by přetekla z obrazovky — MarginContainer nemá pravý okraj.
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(column)

	column.add_child(UITheme.logotype(88))

	_subtitle = UITheme.label("Dustfall, Nevada  ·  1872", UITheme.SIZE_BODY,
		UITheme.PARCHMENT_DIM, UITheme.WEIGHT_REGULAR)
	column.add_child(_subtitle)

	var rule := HSeparator.new()
	rule.custom_minimum_size = Vector2(MENU_WIDTH, 0)
	column.add_child(rule)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	column.add_child(gap)

	_menu_column = UITheme.column(UITheme.GAP)
	_menu_column.custom_minimum_size = Vector2(MENU_WIDTH, 0)
	column.add_child(_menu_column)


# --- Obrazovky ---------------------------------------------------------------

func _show_first_run() -> void:
	_set_subtitle("Zkrachovalý inženýr. Dvanáct dolarů. A jedna poslední šance.")
	_rebuild([
		{"text": "ZAČÍT", "primary": true, "action": _start_tutorial},
		{"text": "Přeskočit úvod", "action": _show_mode_choice},
		{"text": "Konec", "action": _quit},
	])


func _show_main() -> void:
	_set_subtitle("Dustfall, Nevada  ·  1872")
	var entries := [{"text": "HRÁT", "primary": true, "action": _show_mode_choice}]
	if _has_any_save():
		entries.append({"text": "Pokračovat", "action": _continue_game})
	entries.append({"text": "Tutoriál", "action": _start_tutorial})
	entries.append({"text": "Konec", "action": _quit})
	_rebuild(entries)


func _show_mode_choice() -> void:
	_set_subtitle("Vyberte obtížnost — jde změnit jen novou hrou.")
	_rebuild([
		{
			"text": "ZAČÁTEČNÍK",
			"primary": true,
			"note": "Harlan-Voss vás nemůže zničit. Prohrajete jen tím, že\nnestihnete dostavět železnici včas.",
			"action": func() -> void: _start_game(Ruleset.BEGINNER),
		},
		{
			"text": "POKROČILÝ",
			"note": "Korporace útočí, přizpůsobuje se vašemu stylu a může vám\nvzít Dustfall. Stavby vyžadují nářadí.",
			"action": func() -> void: _start_game(Ruleset.ADVANCED),
		},
		{"text": "Tutoriál", "action": _start_tutorial},
		{"text": "Zpět", "action": _show_main},
	])


func _rebuild(entries: Array) -> void:
	for child in _menu_column.get_children():
		_menu_column.remove_child(child)
		child.queue_free()

	for entry in entries:
		var button := UITheme.button(String(entry["text"]))
		button.custom_minimum_size = Vector2(MENU_WIDTH, 52)
		if bool(entry.get("primary", false)):
			button.add_theme_font_override("font", UITheme.body_font(UITheme.WEIGHT_BOLD))
			button.add_theme_font_size_override("font_size", UITheme.SIZE_HEADING)
			button.add_theme_constant_override("font_spacing_glyph", 2)
			button.add_theme_stylebox_override("normal", _primary_style(UITheme.BRASS_DEEP))
			button.add_theme_stylebox_override("hover", _primary_style(Color(0.404, 0.310, 0.145)))
		button.pressed.connect(entry["action"])
		_menu_column.add_child(button)

		# Popisek pod tlacitkem — obtiznost potrebuje vysvetlit hned tady,
		# ne az ve hre, kdyz uz se s ni neda nic delat.
		if entry.has("note"):
			var note := UITheme.label(String(entry["note"]), UITheme.SIZE_SMALL,
				UITheme.PARCHMENT_DIM)
			note.add_theme_constant_override("line_spacing", 2)
			_menu_column.add_child(note)
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 6)
			_menu_column.add_child(gap)


func _set_subtitle(text: String) -> void:
	_subtitle.text = text


func _primary_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = UITheme.BRASS
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(UITheme.RADIUS)
	style.set_content_margin_all(UITheme.GAP)
	return style


# --- Akce --------------------------------------------------------------------

func _start_game(mode: String) -> void:
	AppConfig.set_value("seen_intro", true)
	AppConfig.set_value("last_mode", mode)
	GameState.pending_mode = mode
	GameState.pending_tutorial = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _start_tutorial() -> void:
	AppConfig.set_value("seen_intro", true)
	AppConfig.set_value("last_mode", Ruleset.BEGINNER)
	GameState.pending_mode = Ruleset.BEGINNER
	# Samotny obsah tutorialu dodava Etapa 4; priznak uz ale musi cestovat
	# spravnou cestou, aby se pak nemenil tok menu.
	GameState.pending_tutorial = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _continue_game() -> void:
	AppConfig.set_value("seen_intro", true)
	GameState.pending_mode = String(AppConfig.get_value("last_mode"))
	GameState.pending_tutorial = false
	GameState.pending_load_slot = _first_used_slot()
	get_tree().change_scene_to_file(GAME_SCENE)


func _quit() -> void:
	get_tree().quit()


func _has_any_save() -> bool:
	return _first_used_slot() > 0


func _first_used_slot() -> int:
	for slot in range(1, SaveGame.SLOT_COUNT + 1):
		if SaveGame.has_slot(slot):
			return slot
	return 0
