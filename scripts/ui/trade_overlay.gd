class_name TradeOverlay
extends OverlayPanel

## Obchodní stanice Dustfallu.
##
## Three ways to move goods, stacked so their trade-offs are visible side by
## side: the vendor's fixed spread, the drifting market (open only while the
## coach is in town) and the standing faction contracts.

const LOTS: Array[int] = [10, 50]
const TABLE_COLUMNS := 6

var _vendor_table: GridContainer
var _market_status: Label
var _market_table: GridContainer
var _contract_box: VBoxContainer
var _gold_label: Label


func _ready() -> void:
	super()
	set_title("OBCHOD")

	_gold_label = UITheme.label("", 15, UITheme.GOLD)
	content.add_child(_gold_label)

	content.add_child(UITheme.label("KUPEC — pevné ceny, otevřeno vždy", 15, UITheme.GOLD))
	_vendor_table = _new_table()
	content.add_child(_vendor_table)

	content.add_child(HSeparator.new())
	content.add_child(UITheme.label("TRH — kolísavé ceny bez marže", 15, UITheme.GOLD))
	_market_status = UITheme.label("", 13, UITheme.DIM)
	content.add_child(_market_status)
	_market_table = _new_table()
	content.add_child(_market_table)

	content.add_child(HSeparator.new())
	content.add_child(UITheme.label("KONTRAKTY", 15, UITheme.GOLD))
	_contract_box = UITheme.column(6)
	content.add_child(_contract_box)

	GameState.resources_changed.connect(_on_state_changed)
	GameState.contracts_changed.connect(_on_signal_changed)
	GameState.market_changed.connect(_on_signal_changed)


func _on_state_changed(_resources: Dictionary) -> void:
	if visible:
		refresh()


func _on_signal_changed() -> void:
	if visible:
		refresh()


func refresh() -> void:
	_gold_label.text = "Pokladna: %d zlata   ·   kapacita skladu: %d" % [
		int(GameState.resources.get("gold", 0)), GameState.storage_capacity()
	]

	_fill_table(_vendor_table, false)

	var open := GameState.market_open()
	if open:
		_market_status.text = "Dostavník je ve městě — trh je otevřen (odjíždí za %d tahy)." \
			% int(GameState.coach_stay)
	else:
		_market_status.text = "Zavřeno. Trh funguje jen když je ve městě dostavník (dorazí za %d tahů)." \
			% maxi(int(GameState.coach_in), 0)
	_market_status.add_theme_color_override("font_color",
		UITheme.POSITIVE if open else UITheme.DIM)
	_market_table.visible = open
	if open:
		_fill_table(_market_table, true)

	_fill_contracts()


# --- Goods tables ------------------------------------------------------------

func _new_table() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = TABLE_COLUMNS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	return grid


func _fill_table(grid: GridContainer, at_market: bool) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	for header in ["Zboží", "Skladem", "Nákup", "", "Prodej", ""]:
		grid.add_child(UITheme.label(header, 13, UITheme.DIM))

	for resource in GameData.TRADE_GOODS:
		var buy_price := GameState.trade_price(resource, true, at_market)
		var sell_price := GameState.trade_price(resource, false, at_market)
		var stock := int(GameState.resources.get(resource, 0))

		grid.add_child(UITheme.label(GameData.RESOURCE_LABELS[resource], 14, UITheme.PARCHMENT))

		var stock_label := UITheme.label(str(stock), 14, UITheme.PARCHMENT)
		stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stock_label.custom_minimum_size = Vector2(56, 0)
		grid.add_child(stock_label)

		grid.add_child(UITheme.label("%d zl." % buy_price, 14, UITheme.NEGATIVE))
		grid.add_child(_lot_buttons(resource, buy_price, at_market, true))

		grid.add_child(UITheme.label("%d zl." % sell_price, 14, UITheme.POSITIVE))
		grid.add_child(_lot_buttons(resource, sell_price, at_market, false))


func _lot_buttons(resource: String, unit_price: int, at_market: bool, buying: bool) -> Control:
	var row := UITheme.row(4)

	for lot in LOTS:
		var button := UITheme.button("%s%d" % ["+" if buying else "−", lot], Vector2(52, 26))
		button.tooltip_text = "%s %d × %s za %d zlata" % [
			"Koupit" if buying else "Prodat", lot,
			GameData.RESOURCE_LABELS[resource], unit_price * lot
		]
		button.disabled = not _can_trade(resource, lot, at_market, buying)
		button.pressed.connect(func() -> void: _trade(resource, lot, at_market, buying))
		row.add_child(button)

	if not buying:
		var stock := int(GameState.resources.get(resource, 0))
		var all_button := UITheme.button("vše", Vector2(46, 26))
		all_button.tooltip_text = "Prodat vše (%d) za %d zlata" % [stock, unit_price * stock]
		all_button.disabled = stock <= 0 or (at_market and not GameState.market_open())
		all_button.pressed.connect(func() -> void: _trade(resource, stock, at_market, false))
		row.add_child(all_button)

	return row


func _can_trade(resource: String, amount: int, at_market: bool, buying: bool) -> bool:
	if at_market and not GameState.market_open():
		return false
	if buying:
		var price := GameState.trade_price(resource, true, at_market)
		if int(GameState.resources.get("gold", 0)) < price * amount:
			return false
		return GameState.storage_capacity() - int(GameState.resources.get(resource, 0)) >= amount
	return int(GameState.resources.get(resource, 0)) >= amount


func _trade(resource: String, amount: int, at_market: bool, buying: bool) -> void:
	var result: Dictionary = GameState.buy(resource, amount, at_market) if buying \
		else GameState.sell(resource, amount, at_market)
	if not bool(result["ok"]):
		GameState.notify(String(result["reason"]), "warning")
	refresh()


# --- Contracts ---------------------------------------------------------------

func _fill_contracts() -> void:
	for child in _contract_box.get_children():
		_contract_box.remove_child(child)
		child.queue_free()

	if GameState.contracts.is_empty():
		_contract_box.add_child(UITheme.label(
			"Žádné otevřené kontrakty. Nové nabídky chodí každých %d tahů." \
				% GameData.CONTRACT_INTERVAL,
			13, UITheme.DIM
		))
		return

	for contract in GameState.contracts:
		_contract_box.add_child(_contract_card(contract))


func _contract_card(contract: Dictionary) -> Control:
	var resource: String = contract["resource"]
	var amount := int(contract["amount"])
	var stock := int(GameState.resources.get(resource, 0))
	var ready := stock >= amount
	var turns := int(contract["turns_left"])

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card_style(
		UITheme.CARD_BG if ready else UITheme.CARD_BG_MUTED,
		Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.7) if ready
			else UITheme.MUTED_BORDER
	))

	var row := UITheme.row(12)
	card.add_child(row)

	var column := UITheme.column(2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)

	column.add_child(UITheme.label(String(contract["faction_name"]), 15, UITheme.GOLD))
	column.add_child(UITheme.label("Dodat %d × %s — máte %d" % [
		amount, GameData.RESOURCE_LABELS[resource], stock
	], 13, UITheme.PARCHMENT if ready else UITheme.NEGATIVE))
	column.add_child(UITheme.label("Odměna: %d zlata, +%d %s" % [
		int(contract["reward_gold"]), int(contract["reward_reputation"]),
		GameData.REPUTATION_LABELS[contract["track"]].to_lower()
	], 13, UITheme.DIM))

	var right := UITheme.column(4)
	row.add_child(right)

	var deadline := UITheme.label("Zbývá %d tahů" % turns, 13,
		UITheme.NEGATIVE if turns <= 2 else UITheme.DIM)
	right.add_child(deadline)

	var button := UITheme.button("Splnit", Vector2(120, 30))
	button.disabled = not ready
	button.pressed.connect(func() -> void:
		var result: Dictionary = GameState.fulfill_contract(int(contract["id"]))
		if not bool(result["ok"]):
			GameState.notify(String(result["reason"]), "warning")
		refresh()
	)
	right.add_child(button)

	return card
