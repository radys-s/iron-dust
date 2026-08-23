class_name TechOverlay
extends OverlayPanel

## The five-branch technology tree. Cards show state at a glance: owned, ready to
## research, or still locked behind prerequisites.

const CARD_WIDTH := 210.0

var _points_label: Label
var _branches: HBoxContainer


func _ready() -> void:
	super()
	set_title("TECHNOLOGICKÝ STROM")

	_points_label = UITheme.label("", 15, UITheme.GOLD)
	content.add_child(_points_label)

	_branches = UITheme.row(14)
	content.add_child(_branches)

	GameState.tech_researched.connect(_on_tech_researched)


func _on_tech_researched(_id: String) -> void:
	if visible:
		refresh()


func refresh() -> void:
	_points_label.text = "Dostupné technologické body: %d   ·   celkem získáno: %d" % [
		GameState.tech_points, GameState.tech_total_earned
	]

	for child in _branches.get_children():
		_branches.remove_child(child)
		child.queue_free()

	for branch in GameData.TECH_BRANCHES:
		var column := UITheme.column(6)
		column.custom_minimum_size = Vector2(CARD_WIDTH, 0)
		_branches.add_child(column)

		column.add_child(UITheme.label(_branch_label(branch), 15, UITheme.GOLD))
		column.add_child(HSeparator.new())

		for node in GameData.TECH_NODES:
			if node["branch"] != branch:
				continue
			column.add_child(_card(node))


func _branch_label(branch: String) -> String:
	match branch:
		"industry":
			return "PRŮMYSL"
		"transport":
			return "DOPRAVA"
		"politics":
			return "POLITIKA"
		"war":
			return "VÁLKA"
		"combined":
			return "KOMBINOVANÉ"
	return branch.to_upper()


func _card(node: Dictionary) -> Control:
	var id: String = node["id"]
	var owned := GameState.has_tech(id)
	var available := GameState.can_research(id)

	var card := PanelContainer.new()
	if owned:
		card.add_theme_stylebox_override("panel",
			UITheme.card_style(UITheme.CARD_BG_ACTIVE, UITheme.GOLD))
	elif available:
		card.add_theme_stylebox_override("panel", UITheme.card_style(
			UITheme.CARD_BG, Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.7)
		))
	else:
		card.add_theme_stylebox_override("panel",
			UITheme.card_style(UITheme.CARD_BG_MUTED, UITheme.MUTED_BORDER))

	var column := UITheme.column(2)
	card.add_child(column)

	var title := "%s%s" % ["✔ " if owned else "", node["name"]]
	column.add_child(UITheme.label(title, 15,
		UITheme.GOLD if (owned or available) else UITheme.DIM))

	column.add_child(UITheme.wrapped_label(node["desc"], 12,
		UITheme.PARCHMENT if (owned or available) else UITheme.DIM, CARD_WIDTH - 24.0))

	if owned:
		return card

	column.add_child(UITheme.label("Cena: %d bodů" % node["cost"], 12,
		UITheme.GOLD if available else UITheme.DIM))

	if not available:
		var missing := _missing_requirements(node)
		if not missing.is_empty():
			column.add_child(UITheme.wrapped_label(
				"Vyžaduje: %s" % ", ".join(missing), 11, UITheme.DIM, CARD_WIDTH - 24.0
			))

	var button := UITheme.button("Vyzkoumat" if available else "Nedostupné")
	button.disabled = not available
	button.pressed.connect(func() -> void:
		GameState.research(node["id"])
		refresh()
	)
	column.add_child(button)
	return card


func _missing_requirements(node: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for required in node["requires"]:
		if not GameState.has_tech(required):
			out.append(String(GameData.find_tech(required).get("name", required)))
	return out
