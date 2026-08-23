extends CanvasLayer

## Iron Dust HUD: resource ledger, turn control, selected-tile panel, notification
## feed and the tech tree overlay. Built in code so the whole layout lives in one
## reviewable place; it reads GameState through signals only.

const PANEL_BG := Color(0.09, 0.075, 0.06, 0.92)
const GOLD := Color(0.83, 0.66, 0.33)
const PARCHMENT := Color(0.95, 0.89, 0.74)
const DIM := Color(0.62, 0.55, 0.44)
const POSITIVE := Color(0.44, 0.79, 0.47)
const NEGATIVE := Color(0.85, 0.36, 0.30)

const NOTIFICATION_SECONDS := 4.0
const MAX_NOTIFICATIONS := 5

var _resource_values: Dictionary = {}
var _resource_nets: Dictionary = {}
var _turn_label: Label
var _population_label: Label
var _coach_label: Label
var _tech_points_label: Label
var _notification_box: VBoxContainer
var _tile_panel: PanelContainer
var _tile_title: Label
var _tile_body: Label
var _tech_overlay: PanelContainer
var _tech_grid: HBoxContainer
var _root: Control


func _ready() -> void:
	# Everything hangs off one full-rect Control so panels can be placed with
	# anchors. Manual position maths races the layout engine, which left the tech
	# overlay hanging off the bottom of the screen.
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_resource_panel()
	_build_tile_panel()
	_build_action_bar()
	_build_notifications()
	_build_tech_overlay()

	GameState.resources_changed.connect(_on_resources_changed)
	GameState.turn_advanced.connect(_on_turn_advanced)
	GameState.notified.connect(_on_notified)
	GameState.reputation_changed.connect(func(_r): _refresh_header())
	GameState.tech_researched.connect(func(_id): _refresh_tech_overlay())
	# Child _ready() runs before the parent scene loads the map, so the first
	# header would otherwise show the economy of an empty world.
	GameState.map_changed.connect(_refresh_header)

	_on_resources_changed(GameState.resources)
	_refresh_header()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_T:
				_toggle_tech()
			KEY_ENTER, KEY_KP_ENTER:
				GameState.advance_turn()
			KEY_ESCAPE:
				if _tech_overlay.visible:
					_tech_overlay.hide()


# --- Construction ------------------------------------------------------------

func _styled_panel(bg: Color = PANEL_BG) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(12)
	return style


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _build_resource_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _styled_panel())
	panel.custom_minimum_size = Vector2(320, 0)
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 20)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	column.add_child(_label("IRON DUST", 24, GOLD))

	_turn_label = _label("", 15, PARCHMENT)
	column.add_child(_turn_label)

	var separator := HSeparator.new()
	column.add_child(separator)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	column.add_child(grid)

	for key in GameData.RESOURCES:
		grid.add_child(_label(GameData.RESOURCE_LABELS[key] + ":", 15, DIM))

		var value := _label("0", 15, PARCHMENT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(66, 0)
		grid.add_child(value)
		_resource_values[key] = value

		var net := _label("", 13, DIM)
		net.custom_minimum_size = Vector2(52, 0)
		grid.add_child(net)
		_resource_nets[key] = net

	column.add_child(HSeparator.new())

	_population_label = _label("", 13, DIM)
	column.add_child(_population_label)
	_coach_label = _label("", 13, DIM)
	column.add_child(_coach_label)
	_tech_points_label = _label("", 13, GOLD)
	column.add_child(_tech_points_label)


func _build_tile_panel() -> void:
	_tile_panel = PanelContainer.new()
	_tile_panel.add_theme_stylebox_override("panel", _styled_panel())
	_tile_panel.custom_minimum_size = Vector2(300, 0)
	_tile_panel.hide()
	_root.add_child(_tile_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_tile_panel.add_child(column)

	_tile_title = _label("", 19, GOLD)
	column.add_child(_tile_title)

	_tile_body = _label("", 14, PARCHMENT)
	_tile_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tile_body.custom_minimum_size = Vector2(276, 0)
	column.add_child(_tile_body)

	_reposition_tile_panel()


## Re-applied whenever the text changes, since the preset sizes to the current
## minimum size and the panel grows with its content.
func _reposition_tile_panel() -> void:
	_tile_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20
	)


func _build_action_bar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	_root.add_child(bar)

	var tech_button := Button.new()
	tech_button.text = "TECH STROM  [T]"
	tech_button.custom_minimum_size = Vector2(190, 44)
	tech_button.pressed.connect(_toggle_tech)
	bar.add_child(tech_button)

	var turn_button := Button.new()
	turn_button.text = "KONEC TAHU  [Enter]"
	turn_button.custom_minimum_size = Vector2(220, 44)
	turn_button.pressed.connect(GameState.advance_turn)
	bar.add_child(turn_button)

	bar.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 20
	)


func _build_notifications() -> void:
	_notification_box = VBoxContainer.new()
	_notification_box.add_theme_constant_override("separation", 5)
	_notification_box.custom_minimum_size = Vector2(420, 0)
	_root.add_child(_notification_box)

	_notification_box.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20
	)
	# Newest entry is appended at the bottom, so the stack has to grow upward.
	_notification_box.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_tech_overlay() -> void:
	# A full-rect CenterContainer keeps the overlay centred no matter how the
	# card layout changes, without measuring anything by hand.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)

	_tech_overlay = PanelContainer.new()
	_tech_overlay.add_theme_stylebox_override("panel", _styled_panel(Color(0.07, 0.06, 0.05, 0.97)))
	_tech_overlay.hide()
	centre.add_child(_tech_overlay)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_tech_overlay.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_child(_label("TECHNOLOGICKÝ STROM", 24, GOLD))

	var close := Button.new()
	close.text = "✕  [Esc]"
	close.pressed.connect(_tech_overlay.hide)
	header.add_child(close)

	_tech_grid = HBoxContainer.new()
	_tech_grid.add_theme_constant_override("separation", 14)
	column.add_child(_tech_grid)


func _toggle_tech() -> void:
	_tech_overlay.visible = not _tech_overlay.visible
	if _tech_overlay.visible:
		_refresh_tech_overlay()


func _refresh_tech_overlay() -> void:
	for child in _tech_grid.get_children():
		child.queue_free()

	for branch in GameData.TECH_BRANCHES:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		column.custom_minimum_size = Vector2(210, 0)
		_tech_grid.add_child(column)

		column.add_child(_label(branch.to_upper(), 15, GOLD))
		column.add_child(HSeparator.new())

		for node in GameData.TECH_NODES:
			if node["branch"] != branch:
				continue
			column.add_child(_build_tech_card(node))

	_refresh_header()


func _build_tech_card(node: Dictionary) -> Control:
	var id: String = node["id"]
	var owned := GameState.has_tech(id)
	var available := GameState.can_research(id)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	style.set_border_width_all(1)
	if owned:
		style.bg_color = Color(0.24, 0.19, 0.08, 0.95)
		style.border_color = GOLD
	elif available:
		style.bg_color = Color(0.15, 0.13, 0.10, 0.95)
		style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.7)
	else:
		style.bg_color = Color(0.10, 0.09, 0.08, 0.9)
		style.border_color = Color(0.3, 0.28, 0.25, 0.6)
	card.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)

	var title := "%s%s" % ["✔ " if owned else "", node["name"]]
	column.add_child(_label(title, 15, GOLD if (owned or available) else DIM))

	var desc := _label(node["desc"], 12, PARCHMENT if available or owned else DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(186, 0)
	column.add_child(desc)

	if not owned:
		var footer := _label("Cena: %d" % node["cost"], 12, GOLD if available else DIM)
		column.add_child(footer)

		var button := Button.new()
		button.text = "Vyzkoumat" if available else "Nedostupné"
		button.disabled = not available
		button.pressed.connect(func() -> void:
			GameState.research(id)
			_refresh_tech_overlay()
		)
		column.add_child(button)

	return card


# --- Signals -----------------------------------------------------------------

func _on_resources_changed(resources: Dictionary) -> void:
	for key in GameData.RESOURCES:
		if _resource_values.has(key):
			_resource_values[key].text = str(resources.get(key, 0))
	_refresh_header()


func _on_turn_advanced(_turn: int, _season: String, _year: int) -> void:
	_refresh_header()


func _refresh_header() -> void:
	_turn_label.text = "%s %d  ·  tah %d" % [GameState.season, GameState.year, GameState.turn_count]
	_population_label.text = "Populace: %d   ·   kapacita skladu: %d" % [
		GameState.population, GameState.storage_capacity()
	]
	_coach_label.text = "Dostavník za: %d tahů" % maxi(GameState.coach_in, 0)
	_tech_points_label.text = "Tech body: %d" % GameState.tech_points

	var net: Dictionary = GameState.economy.get("net", {})
	for key in GameData.RESOURCES:
		if not _resource_nets.has(key):
			continue
		var value := int(net.get(key, 0))
		var label: Label = _resource_nets[key]
		label.text = "%+d" % value if value != 0 else "—"
		label.add_theme_color_override("font_color",
			POSITIVE if value > 0 else (NEGATIVE if value < 0 else DIM))


func _on_notified(text: String, type: String) -> void:
	var color := PARCHMENT
	match type:
		"success":
			color = POSITIVE
		"warning":
			color = NEGATIVE
		"production":
			color = GOLD

	var panel := PanelContainer.new()
	var style := _styled_panel(Color(0.08, 0.07, 0.06, 0.88))
	style.set_content_margin_all(7)
	style.border_color = Color(color.r, color.g, color.b, 0.5)
	panel.add_theme_stylebox_override("panel", style)

	var label := _label(text, 14, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(400, 0)
	panel.add_child(label)

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


# --- Called by the map scene -------------------------------------------------

func show_tile(cell: Vector2i, terrain: GameData.Terrain) -> void:
	_tile_title.text = GameData.TERRAIN_NAMES[terrain]

	var lines: Array[String] = [GameData.TERRAIN_DESCRIPTIONS[terrain]]
	lines.append("")
	lines.append("Pozice: q=%d r=%d" % [cell.x, cell.y])

	if GameData.TERRAIN_YIELDS.has(terrain):
		var parts: Array[String] = []
		for key in GameData.TERRAIN_YIELDS[terrain]:
			parts.append("%s +%d" % [GameData.RESOURCE_LABELS[key], GameData.TERRAIN_YIELDS[terrain][key]])
		lines.append("Výnos za tah: %s" % ", ".join(parts))
	else:
		lines.append("Výnos za tah: žádný")

	_tile_body.text = "\n".join(lines)
	_tile_panel.show()
	_reposition_tile_panel()


func hide_tile() -> void:
	_tile_panel.hide()
