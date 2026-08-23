class_name BuildOverlay
extends OverlayPanel

## The catalogue of buildings.
##
## Opened two ways. From a tile ("Postavit budovu") it carries that hex and puts
## the chosen building straight onto it. From the action bar it carries no hex,
## and picking a building hands the player a placement cursor instead — the cell
## in the signal is Vector2i.MAX in that case.

signal build_chosen(building_name: String, cell: Vector2i)

const CARD_WIDTH := 260.0
const COLUMNS := 4

var _target: Vector2i = Vector2i.MAX
var _subtitle: Label
var _grid: GridContainer


func _ready() -> void:
	super()
	set_title("STAVBY")

	_subtitle = UITheme.label("", 14, UITheme.DIM)
	content.add_child(_subtitle)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(_grid)

	GameState.resources_changed.connect(_on_resources_changed)


func _on_resources_changed(_resources: Dictionary) -> void:
	if visible:
		refresh()


## Opens the catalogue bound to one hex.
func open_for(cell: Vector2i) -> void:
	_target = cell
	open()


## Opens the catalogue with no hex chosen yet.
func open_free() -> void:
	_target = Vector2i.MAX
	open()


func refresh() -> void:
	if _target == Vector2i.MAX:
		_subtitle.text = "Vyberte stavbu — pak kliknete na dlaždici, kam má stát."
	else:
		_subtitle.text = "Staví se na dlaždici %d:%d (%s)." % [
			_target.x, _target.y, GameData.TERRAIN_NAMES[GameState.get_tile(_target)]
		]

	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	for entry in GameData.BUILDABLES:
		_grid.add_child(_card(entry))


func _card(entry: Dictionary) -> Control:
	var affordable := GameState.can_afford(entry["costs"])

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card_style(
		UITheme.CARD_BG if affordable else UITheme.CARD_BG_MUTED,
		Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.7) if affordable
			else UITheme.MUTED_BORDER
	))

	var column := UITheme.column(3)
	card.add_child(column)

	column.add_child(UITheme.label(entry["name"], 16,
		UITheme.GOLD if affordable else UITheme.DIM))
	column.add_child(UITheme.wrapped_label(entry["effect"], 12,
		UITheme.PARCHMENT if affordable else UITheme.DIM, CARD_WIDTH - 24.0))

	var cost_text := "Cena: %s" % GameData.format_costs(entry["costs"])
	column.add_child(UITheme.wrapped_label(cost_text, 12,
		UITheme.GOLD if affordable else UITheme.NEGATIVE, CARD_WIDTH - 24.0))

	if not affordable:
		column.add_child(UITheme.wrapped_label(
			"Chybí: %s" % GameData.format_costs(GameState.missing_costs(entry["costs"])),
			11, UITheme.NEGATIVE, CARD_WIDTH - 24.0
		))

	var button := UITheme.button(
		"Postavit zde" if _target != Vector2i.MAX else "Vybrat a umístit"
	)
	button.disabled = not affordable
	button.pressed.connect(func() -> void:
		var cell := _target
		close()
		build_chosen.emit(String(entry["name"]), cell)
	)
	column.add_child(button)

	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	return card
