class_name SaveOverlay
extends OverlayPanel

## Three save slots plus a fresh start. Slot headers are read straight from the
## files, so the panel shows what is in them without loading a game.

const NEW_GAME_SEED := 18720412

var _slot_box: VBoxContainer


func _ready() -> void:
	super()
	set_title("ULOŽENÉ HRY")

	content.add_child(UITheme.label(
		"Uloženo v user:// — mimo projekt, takže přežije i reinstalaci.",
		13, UITheme.DIM
	))

	_slot_box = UITheme.column(8)
	content.add_child(_slot_box)

	content.add_child(HSeparator.new())

	var new_game := UITheme.button("Nová hra (zahodí neuložený postup)", Vector2(340, 34))
	new_game.pressed.connect(func() -> void:
		close()
		GameState.start_new_game(NEW_GAME_SEED)
		GameState.notify("Nová hra. Vítejte v Dustfallu.", "success")
	)
	content.add_child(new_game)


func refresh() -> void:
	for child in _slot_box.get_children():
		_slot_box.remove_child(child)
		child.queue_free()

	for slot in range(1, SaveGame.SLOT_COUNT + 1):
		_slot_box.add_child(_slot_row(slot))


func _slot_row(slot: int) -> Control:
	var info := SaveGame.slot_info(slot)
	var exists := bool(info.get("exists", false))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card_style(
		UITheme.CARD_BG if exists else UITheme.CARD_BG_MUTED,
		Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.7) if exists
			else UITheme.MUTED_BORDER
	))

	var row := UITheme.row(12)
	card.add_child(row)

	var column := UITheme.column(2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size = Vector2(340, 0)
	row.add_child(column)

	column.add_child(UITheme.label("Slot %d" % slot, 15, UITheme.GOLD))
	if exists:
		column.add_child(UITheme.label("%s · %s %d · tah %d · %d zlata" % [
			info["player"], info["season"], int(info["year"]),
			int(info["turn"]), int(info["gold"])
		], 13, UITheme.PARCHMENT))
	else:
		column.add_child(UITheme.label("prázdný", 13, UITheme.DIM))

	var save_button := UITheme.button("Uložit", Vector2(96, 30))
	save_button.pressed.connect(func() -> void:
		GameState.save_to_slot(slot)
		refresh()
	)
	row.add_child(save_button)

	var load_button := UITheme.button("Načíst", Vector2(96, 30))
	load_button.disabled = not exists
	load_button.pressed.connect(func() -> void:
		if GameState.load_from_slot(slot):
			close()
		else:
			refresh()
	)
	row.add_child(load_button)

	var delete_button := UITheme.button("Smazat", Vector2(96, 30))
	delete_button.disabled = not exists
	delete_button.pressed.connect(func() -> void:
		SaveGame.delete_slot(slot)
		GameState.notify("Slot %d smazán." % slot, "info")
		refresh()
	)
	row.add_child(delete_button)

	return card
