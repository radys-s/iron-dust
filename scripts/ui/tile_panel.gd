class_name TilePanel
extends PanelContainer

## The selected-hex panel: what is there, who owns it, what it yields, and every
## action the player may take on it — each button carrying its price and, when
## it is disabled, the reason why.

signal action_chosen(action_id: String, cell: Vector2i)

const PANEL_WIDTH := 340.0
const TEXT_WIDTH := PANEL_WIDTH - 26.0

var _cell: Vector2i = Vector2i.MAX
var _title: Label
var _body: VBoxContainer
var _actions: VBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.panel_style())
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	hide()

	var column := UITheme.column(6)
	add_child(column)

	_title = UITheme.heading("")
	column.add_child(_title)

	_body = UITheme.column(3)
	column.add_child(_body)

	column.add_child(HSeparator.new())

	_actions = UITheme.column(5)
	column.add_child(_actions)

	GameState.resources_changed.connect(_on_state_changed)
	GameState.map_changed.connect(_refresh_if_open)


func _on_state_changed(_resources: Dictionary) -> void:
	_refresh_if_open()


func _refresh_if_open() -> void:
	if visible and _cell != Vector2i.MAX:
		show_cell(_cell)


func current_cell() -> Vector2i:
	return _cell


func show_cell(cell: Vector2i) -> void:
	_cell = cell
	var terrain := GameState.get_tile(cell)

	_title.text = GameData.TERRAIN_NAMES[terrain]
	_fill_body(cell, terrain)
	_fill_actions(cell)
	show()


func close() -> void:
	_cell = Vector2i.MAX
	hide()


# --- Body --------------------------------------------------------------------

func _fill_body(cell: Vector2i, terrain: GameData.Terrain) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	_body.add_child(UITheme.wrapped_label(
		GameData.TERRAIN_DESCRIPTIONS[terrain], 13, UITheme.PARCHMENT, TEXT_WIDTH
	))

	var owner_text := "Vaše území" if GameState.is_owned(cell) else "Nezabrané"
	if terrain == GameData.Terrain.ENEMY:
		owner_text = "Harlan-Voss"
	_body.add_child(UITheme.label("Pozice q=%d r=%d   ·   %s" % [
		cell.x, cell.y, owner_text
	], 12, UITheme.DIM))

	_body.add_child(UITheme.label("Výnos za tah: %s" % _yield_text(cell, terrain),
		13, UITheme.GOLD))

	var level: int = GameState.settlement_at(cell)
	if level > 0:
		var data := GameData.settlement_data(level)
		_body.add_child(UITheme.wrapped_label(
			"%s — dosah zásobování %d, obrana +%d, produkce %s" % [
				data["name"], int(data["supply"]), int(data["defense"]),
				GameData.format_costs(data["production"])
			], 13, UITheme.POSITIVE, TEXT_WIDTH))

	var building: Dictionary = GameState.building_at(cell)
	if not building.is_empty():
		var production: Dictionary = building.get("production", {})
		var effect := GameData.format_costs(production) if not production.is_empty() \
			else String(GameData.find_buildable(building["name"]).get("effect", ""))
		_body.add_child(UITheme.wrapped_label(
			"Stavba: %s (%s)" % [building["name"], effect], 13, UITheme.POSITIVE, TEXT_WIDTH))

	if terrain == GameData.Terrain.ENEMY:
		_body.add_child(_combat_preview(cell))


func _yield_text(cell: Vector2i, terrain: GameData.Terrain) -> String:
	var parts: Array[String] = []
	if GameData.TERRAIN_YIELDS.has(terrain):
		for key in GameData.TERRAIN_YIELDS[terrain]:
			parts.append("%s +%d" % [
				GameData.RESOURCE_LABELS[key], int(GameData.TERRAIN_YIELDS[terrain][key])
			])
	# A claim on terrain that is not already yours adds a toll on top.
	if GameState.owned.has(cell) and not GameData.INHERENTLY_OWNED.has(terrain):
		for key in GameData.CLAIM_BONUS:
			parts.append("%s +%d (zábor)" % [
				GameData.RESOURCE_LABELS[key], int(GameData.CLAIM_BONUS[key])
			])
	return ", ".join(parts) if not parts.is_empty() else "žádný"


func _combat_preview(cell: Vector2i) -> Control:
	var preview: Dictionary = GameState.combat_preview(cell)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		UITheme.card_style(UITheme.CARD_BG_MUTED, UITheme.MUTED_BORDER))

	var column := UITheme.column(2)
	card.add_child(column)
	column.add_child(UITheme.label("Naše síla %d  ·  jejich %d  (+k6 obě strany)" % [
		int(preview["player"]), int(preview["enemy"])
	], 13, UITheme.PARCHMENT))
	column.add_child(UITheme.wrapped_label(String(preview["forecast"]), 12,
		UITheme.amount_color(int(preview["player"]) - int(preview["enemy"])), TEXT_WIDTH - 16.0))
	return card


# --- Actions -----------------------------------------------------------------

func _fill_actions(cell: Vector2i) -> void:
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()

	var actions := GameState.actions_for(cell)
	if actions.is_empty():
		_actions.add_child(UITheme.label("Zde není co dělat.", 13, UITheme.DIM))
		return

	for action in actions:
		_actions.add_child(_action_button(action, cell))


func _action_button(action: Dictionary, cell: Vector2i) -> Control:
	var enabled := bool(action["enabled"])
	var box := UITheme.column(1)

	var label := String(action["name"])
	var costs: Dictionary = action["cost"]
	if not costs.is_empty():
		label += "  —  %s" % GameData.format_costs(costs)

	var button := UITheme.button(label, Vector2(TEXT_WIDTH, 32))
	button.disabled = not enabled
	button.tooltip_text = String(action["hint"])
	button.pressed.connect(func() -> void: action_chosen.emit(String(action["id"]), cell))
	box.add_child(button)

	if not enabled:
		box.add_child(UITheme.wrapped_label(
			String(action["reason"]), 11, UITheme.NEGATIVE, TEXT_WIDTH
		))
	return box
