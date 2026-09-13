extends CanvasLayer

## Iron Dust HUD: the always-on chrome (resource ledger, reputation, turn
## control, notifications, selected-tile panel) plus the four modal overlays.
##
## Everything hangs off one full-rect Control so panels can be placed with
## anchors — manual position maths races the layout engine, which once left the
## tech overlay hanging off the bottom of the screen. The HUD reads GameState
## through signals only; the play scene talks to it through show_tile/hide_tile
## and listens to build_requested.

signal build_requested(building_name: String)

const NOTIFICATION_SECONDS := 4.0
const MAX_NOTIFICATIONS := 5
const COMBAT_BANNER_SECONDS := 6.0
const LEDGER_WIDTH := 330.0

var _root: Control
var _resource_values: Dictionary = {}
var _resource_nets: Dictionary = {}
var _reputation_bars: Dictionary = {}
var _reputation_values: Dictionary = {}
var _turn_label: Label
var _population_label: Label
var _coach_label: Label
var _tech_points_label: Label
var _contract_label: Label
var _notification_box: VBoxContainer

const MinimapScript = preload("res://scripts/ui/minimap.gd")

var _tile_panel: TilePanel
var _minimap: Control
var _tech_overlay: TechOverlay
var _build_overlay: BuildOverlay
var _trade_overlay: TradeOverlay
var _save_overlay: SaveOverlay
var _game_over_overlay: GameOverOverlay
var _combat_banner: PanelContainer


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Jedno prirazeni na koreni — Godot theme propaguje do celeho podstromu,
	# takze se nastyluji i kontroly, ktere si nikdo rucne neupravuje. Presne
	# tohle drív chybelo a proto mela vsechna tlacitka vychozi Godot skin.
	_root.theme = UITheme.build_theme()
	add_child(_root)

	_build_ledger()
	_build_tile_panel()
	_build_action_bar()
	_build_notifications()
	_build_minimap()
	_build_overlays()
	_build_combat_banner()

	GameState.resources_changed.connect(_on_resources_changed)
	GameState.turn_advanced.connect(_on_turn_advanced)
	GameState.notified.connect(_on_notified)
	GameState.reputation_changed.connect(_on_reputation_changed)
	GameState.tech_researched.connect(func(_id: String) -> void: _refresh_header())
	GameState.contracts_changed.connect(_refresh_header)
	GameState.combat_resolved.connect(_show_combat_banner)
	GameState.game_loaded.connect(_on_game_loaded)
	GameState.game_over.connect(_on_game_over)
	# Child _ready() runs before the parent scene loads the map, so the first
	# header would otherwise show the economy of an empty world.
	GameState.map_changed.connect(_refresh_header)

	_on_resources_changed(GameState.resources)
	_on_reputation_changed(GameState.reputation)
	_refresh_header()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_T:
			_toggle_overlay(_tech_overlay)
		KEY_B:
			_open_build_free()
		KEY_O:
			_toggle_overlay(_trade_overlay)
		KEY_F5:
			_toggle_overlay(_save_overlay)
		KEY_ENTER, KEY_KP_ENTER:
			if not _any_overlay_open():
				GameState.advance_turn()
		KEY_ESCAPE:
			_close_overlays()


# --- Ledger ------------------------------------------------------------------

func _build_ledger() -> void:
	var panel := UITheme.panel()
	panel.custom_minimum_size = Vector2(LEDGER_WIDTH, 0)
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 20
	)

	var column := UITheme.column(4)
	panel.add_child(column)

	column.add_child(UITheme.logotype(26))

	_turn_label = UITheme.label("", 15, UITheme.PARCHMENT)
	column.add_child(_turn_label)
	column.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	column.add_child(grid)

	for key in GameData.RESOURCES:
		grid.add_child(UITheme.label(GameData.RESOURCE_LABELS[key] + ":", 15, UITheme.DIM))

		var value := UITheme.label("0", 15, UITheme.PARCHMENT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(66, 0)
		grid.add_child(value)
		_resource_values[key] = value

		var net := UITheme.label("", 13, UITheme.DIM)
		net.custom_minimum_size = Vector2(58, 0)
		grid.add_child(net)
		_resource_nets[key] = net

	column.add_child(HSeparator.new())
	column.add_child(UITheme.label("REPUTACE", 13, UITheme.GOLD))

	var reputation_grid := GridContainer.new()
	reputation_grid.columns = 3
	reputation_grid.add_theme_constant_override("h_separation", 8)
	reputation_grid.add_theme_constant_override("v_separation", 3)
	column.add_child(reputation_grid)

	for track in GameData.REPUTATION_TRACKS:
		reputation_grid.add_child(
			UITheme.label(GameData.REPUTATION_LABELS[track], 13, UITheme.DIM)
		)

		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(120, 12)
		reputation_grid.add_child(bar)
		_reputation_bars[track] = bar

		var value := UITheme.label("0", 13, UITheme.PARCHMENT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(34, 0)
		reputation_grid.add_child(value)
		_reputation_values[track] = value

	column.add_child(HSeparator.new())

	_population_label = UITheme.label("", 13, UITheme.DIM)
	column.add_child(_population_label)
	_coach_label = UITheme.label("", 13, UITheme.DIM)
	column.add_child(_coach_label)
	_contract_label = UITheme.label("", 13, UITheme.DIM)
	column.add_child(_contract_label)
	_tech_points_label = UITheme.label("", 13, UITheme.GOLD)
	column.add_child(_tech_points_label)


# --- Panels ------------------------------------------------------------------

func _build_tile_panel() -> void:
	_tile_panel = TilePanel.new()
	_root.add_child(_tile_panel)
	_tile_panel.action_chosen.connect(_on_tile_action)
	_reposition_tile_panel()


## Re-applied whenever the content changes, since the preset sizes to the current
## minimum size and the panel grows with its text.
func _reposition_tile_panel() -> void:
	_tile_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20
	)


## Lista pres celou sirku obrazovky. Drív mela napevno dane sirky v souctu
## 832 px a kotvila se na CENTER_BOTTOM, takze na 1920 pusobila jako ostruvek
## uprostred. Ted je zakotvena k obema okrajum a tlacitka si sirku deli pomerem
## — funguje to i na jinem rozliseni nez 1920x1080, coz je nutne, protoze
## stretch/aspect je nove "expand".
## Vlastni vyska tlacitek jen pro tuhle listu — Tomas po Etape 1 chtel "dolni
## panel trochu vetsi do vysky". Kdyby se misto toho zvedl globalni
## UITheme.BUTTON_HEIGHT, zvetsi se kazde tlacitko ve hre vcetne dialogu,
## ktere si nikdo nestezoval, ze jsou male.
const ACTION_BAR_BUTTON_HEIGHT := 52.0
## Tlacitko + horni/dolni okraj panelu (_action_bar_style pouziva GAP_LOOSE
## na obe strany) — notifikace vlevo dole potrebuji vedet, jak vysoko nad
## listou zastavit, jinak se s ni prekryvaji (presne tenhle bug se objevil,
## kdyz se lista zvetsila a puvodni pevna 20px mezera uz nestacila).
const ACTION_BAR_TOTAL_HEIGHT := ACTION_BAR_BUTTON_HEIGHT + UITheme.GAP_LOOSE * 2.0

func _build_action_bar() -> void:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _action_bar_style())
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(frame)

	var bar := UITheme.row(UITheme.GAP)
	frame.add_child(bar)

	# Etapa 2 tyhle tri slouci do jedineho tlacitka SPRÁVA, ktere otevre
	# celoobrazovkovou obrazovku se zalozkami. Do te doby zustavaji overlaye.
	var buttons := [
		{"text": "TECH  ·  T", "stretch": 2, "action": func() -> void: _toggle_overlay(_tech_overlay)},
		{"text": "STAVBY  ·  B", "stretch": 2, "action": _open_build_free},
		{"text": "OBCHOD  ·  O", "stretch": 2, "action": func() -> void: _toggle_overlay(_trade_overlay)},
		{"text": "ULOŽIT  ·  F5", "stretch": 2, "action": func() -> void: _toggle_overlay(_save_overlay)},
	]

	for entry in buttons:
		var button := UITheme.button(String(entry["text"]), Vector2(0, ACTION_BAR_BUTTON_HEIGHT))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_stretch_ratio = float(entry["stretch"])
		button.pressed.connect(entry["action"])
		bar.add_child(button)

	# Konec tahu je hlavni akce tahu, takze dostane vlastni vyraznejsi styl
	# a nejvetsi podil sirky — at je jasne, kam se klika, kdyz uz nic nezbyva.
	var end_turn := UITheme.button("KONEC TAHU  ·  ↵", Vector2(0, ACTION_BAR_BUTTON_HEIGHT))
	end_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_turn.size_flags_stretch_ratio = 4.0
	end_turn.add_theme_stylebox_override("normal", _primary_style(UITheme.BRASS_DEEP))
	end_turn.add_theme_stylebox_override("hover", _primary_style(Color(0.376, 0.286, 0.133)))
	end_turn.add_theme_color_override("font_color", UITheme.PARCHMENT)
	end_turn.pressed.connect(GameState.advance_turn)
	bar.add_child(end_turn)

	frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
	frame.offset_left = 0
	frame.offset_right = 0
	frame.offset_bottom = 0


## Listu drzi u zeme rovna horni linka misto zaobleneho ramecku — pusobi to
## jako soucast obrazovky, ne jako plovouci panel.
func _action_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.078, 0.066, 0.057, 0.96)
	style.border_color = UITheme.BRASS_DEEP
	style.border_width_top = 1
	style.content_margin_left = UITheme.PAD
	style.content_margin_right = UITheme.PAD
	style.content_margin_top = UITheme.GAP_LOOSE
	style.content_margin_bottom = UITheme.GAP_LOOSE
	return style


func _primary_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = UITheme.BRASS
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(UITheme.RADIUS)
	style.content_margin_left = UITheme.PAD + 4
	style.content_margin_right = UITheme.PAD + 4
	style.content_margin_top = UITheme.GAP
	style.content_margin_bottom = UITheme.GAP
	return style


func _build_notifications() -> void:
	_notification_box = UITheme.column(5)
	_notification_box.custom_minimum_size = Vector2(420, 0)
	_root.add_child(_notification_box)

	_notification_box.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20
	)
	# Odsazeni od spodu musi pocitat s vyskou akcni listy, jinak novejsi
	# (delsi) notifikace zacnou lezt pod tlacitka.
	_notification_box.offset_bottom = -(ACTION_BAR_TOTAL_HEIGHT + UITheme.GAP_LOOSE)
	# Newest entry is appended at the bottom, so the stack has to grow upward.
	_notification_box.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_minimap() -> void:
	_minimap = MinimapScript.new()
	_minimap.setup(GameState)
	_root.add_child(_minimap)

	# Puvodne set_anchors_and_offsets_preset(..., PRESET_MODE_MINSIZE, 20) a pak
	# jen prepis offset_bottom — jenze MINSIZE preset dá top/bottom oba na -20
	# (nulova vyska pred vynucenim minima) a rucni prepis jen jednoho z nich
	# posunul cely box mimo obrazovku (rostl smerem doprava/dolu od kotevniho
	# bodu, ne dovnitr). Vsechny 4 offsety se proto pocitaji rovnou z rozmeru,
	# ne pres preset.
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	const MARGIN := 20.0
	var bottom_clear := ACTION_BAR_TOTAL_HEIGHT + UITheme.GAP_LOOSE
	_minimap.offset_right = -MARGIN
	_minimap.offset_left = -MARGIN - _minimap.custom_minimum_size.x
	_minimap.offset_bottom = -bottom_clear
	_minimap.offset_top = -bottom_clear - _minimap.custom_minimum_size.y


func _build_overlays() -> void:
	_tech_overlay = TechOverlay.new()
	_build_overlay = BuildOverlay.new()
	_trade_overlay = TradeOverlay.new()
	_save_overlay = SaveOverlay.new()
	_game_over_overlay = GameOverOverlay.new()

	for overlay in [_tech_overlay, _build_overlay, _trade_overlay, _save_overlay, _game_over_overlay]:
		# A full-rect CenterContainer keeps each overlay centred no matter how its
		# content grows, without measuring anything by hand.
		var centre := CenterContainer.new()
		centre.set_anchors_preset(Control.PRESET_FULL_RECT)
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(centre)
		centre.add_child(overlay)

	_build_overlay.build_chosen.connect(_on_build_chosen)
	_game_over_overlay.load_requested.connect(func() -> void: _toggle_overlay(_save_overlay))


func _build_combat_banner() -> void:
	_combat_banner = UITheme.panel(Color(0.10, 0.07, 0.05, 0.96), 14)
	_combat_banner.hide()
	_root.add_child(_combat_banner)


# --- Overlay handling --------------------------------------------------------

func _overlays() -> Array:
	return [_tech_overlay, _build_overlay, _trade_overlay, _save_overlay, _game_over_overlay]


func _any_overlay_open() -> bool:
	for overlay in _overlays():
		if overlay.visible:
			return true
	return false


func _close_overlays() -> void:
	for overlay in _overlays():
		overlay.close()


## Only one modal at a time — opening one closes the rest.
func _toggle_overlay(target: OverlayPanel) -> void:
	var was_open := target.visible
	_close_overlays()
	if not was_open:
		target.open()


func _open_build_free() -> void:
	var was_open := _build_overlay.visible
	_close_overlays()
	if not was_open:
		_build_overlay.open_free()


func _on_tile_action(id: String, cell: Vector2i) -> void:
	match id:
		"build":
			_close_overlays()
			_build_overlay.open_for(cell)
		"trade":
			_toggle_overlay(_trade_overlay)
		_:
			GameState.perform_action(id, cell)
			if _tile_panel.visible:
				_reposition_tile_panel()


func _on_build_chosen(building_name: String, cell: Vector2i) -> void:
	if cell == Vector2i.MAX:
		build_requested.emit(building_name)
		return
	GameState.build(building_name, cell)


# --- State signals -----------------------------------------------------------

func _on_resources_changed(resources: Dictionary) -> void:
	for key in GameData.RESOURCES:
		if _resource_values.has(key):
			_resource_values[key].text = str(int(resources.get(key, 0)))
	_refresh_header()


func _on_reputation_changed(reputation: Dictionary) -> void:
	for track in GameData.REPUTATION_TRACKS:
		if not _reputation_bars.has(track):
			continue
		var value := int(reputation.get(track, 0))
		_reputation_bars[track].value = value
		var label: Label = _reputation_values[track]
		label.text = str(value)
		var color := UITheme.PARCHMENT
		if value < GameData.REPUTATION_LOW:
			color = UITheme.NEGATIVE
		elif value >= GameData.REPUTATION_HIGH:
			color = UITheme.POSITIVE
		label.add_theme_color_override("font_color", color)


func _on_turn_advanced(_turn: int, _season: String, _year: int) -> void:
	_refresh_header()


func _on_game_loaded() -> void:
	_close_overlays()
	_tile_panel.close()
	_on_resources_changed(GameState.resources)
	_on_reputation_changed(GameState.reputation)
	_refresh_header()


func _on_game_over(_reason: String) -> void:
	_close_overlays()
	_tile_panel.close()
	_game_over_overlay.open()


func _refresh_header() -> void:
	_turn_label.text = "%s %d  ·  tah %d" % [
		GameState.season, GameState.year, GameState.turn_count
	]
	_population_label.text = "Populace: %d   ·   sklad: %d" % [
		GameState.population, GameState.storage_capacity()
	]

	if GameState.coach_stay > 0:
		_coach_label.text = "Dostavník ve městě — trh otevřen (%d tahy)" % GameState.coach_stay
		_coach_label.add_theme_color_override("font_color", UITheme.POSITIVE)
	else:
		_coach_label.text = "Dostavník za: %d tahů" % maxi(GameState.coach_in, 0)
		_coach_label.add_theme_color_override("font_color", UITheme.DIM)

	_contract_label.text = "Kontrakty: %d   ·   sídla: %d" % [
		GameState.contracts.size(), GameState.settlements.size()
	]
	_tech_points_label.text = "Tech body: %d" % GameState.tech_points

	var net: Dictionary = GameState.economy.get("net", {})
	for key in GameData.RESOURCES:
		if not _resource_nets.has(key):
			continue
		var value := int(net.get(key, 0))
		var label: Label = _resource_nets[key]
		label.text = "%+d" % value if value != 0 else "—"
		label.add_theme_color_override("font_color", UITheme.amount_color(value))


func _on_notified(text: String, type: String) -> void:
	var color := UITheme.message_color(type)

	var panel := PanelContainer.new()
	var style := UITheme.panel_style(Color(0.08, 0.07, 0.06, 0.88), color, 0.5, 7)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(UITheme.wrapped_label(text, 14, color, 400.0))

	_notification_box.add_child(panel)
	while _notification_box.get_child_count() > MAX_NOTIFICATIONS:
		var oldest := _notification_box.get_child(0)
		_notification_box.remove_child(oldest)
		oldest.queue_free()

	var timer := get_tree().create_timer(NOTIFICATION_SECONDS)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
	)


## Battles deserve more than a one-line notification — this shows the arithmetic.
func _show_combat_banner(report: Dictionary) -> void:
	for child in _combat_banner.get_children():
		_combat_banner.remove_child(child)
		child.queue_free()

	var captured := bool(report["captures"])
	var color := UITheme.POSITIVE if captured else UITheme.NEGATIVE

	var column := UITheme.column(4)
	_combat_banner.add_child(column)
	column.add_child(UITheme.label(String(report["name"]).to_upper(), 22, color))

	if bool(report["capitulated"]):
		column.add_child(UITheme.label(
			"Soudní vliv rozhodl bez boje.", 14, UITheme.PARCHMENT))
	else:
		column.add_child(UITheme.label("My %d + k6 %d = %d   ·   H-V %d + k6 %d = %d" % [
			int(report["player_strength"]), int(report["player_die"]), int(report["player_roll"]),
			int(report["enemy_strength"]), int(report["enemy_die"]), int(report["enemy_roll"]),
		], 15, UITheme.PARCHMENT))

	column.add_child(UITheme.wrapped_label(String(report["text"]), 14, UITheme.PARCHMENT, 460.0))

	var effects: Array[String] = []
	for key in GameData.RESOURCES:
		var amount := int(report["resources"].get(key, 0))
		if amount != 0:
			effects.append("%+d %s" % [amount, GameData.RESOURCE_LABELS[key]])
	for track in report["reputation"]:
		effects.append("%+d %s" % [
			int(report["reputation"][track]), GameData.REPUTATION_LABELS[track].to_lower()
		])
	if not effects.is_empty():
		column.add_child(UITheme.wrapped_label(
			" · ".join(effects), 13, UITheme.DIM, 460.0))

	_combat_banner.show()
	_combat_banner.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24
	)

	var timer := get_tree().create_timer(COMBAT_BANNER_SECONDS)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_combat_banner):
			_combat_banner.hide()
	)


# --- Called by the play scene ------------------------------------------------

func show_tile(cell: Vector2i) -> void:
	_tile_panel.show_cell(cell)
	_reposition_tile_panel()


func hide_tile() -> void:
	_tile_panel.close()


## Mezifáze 2: minimapa potřebuje kameru, aby uměla vykreslit rámeček
## viditelné oblasti a přesouvat pohled na klik/tažení.
func set_camera_rig(rig: IsoCameraRig) -> void:
	_minimap.set_camera_rig(rig)
