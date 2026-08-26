class_name GameOverOverlay
extends OverlayPanel

## Shown once GameState.is_defeated or is_victorious flips true. Closing it
## does not unlock play — GameState itself refuses advance_turn()/
## perform_action() from then on either way, so this overlay only ever needs
## to offer a way out: a fresh start, or loading an earlier save.

signal load_requested()

var _reason_label: Label


func _ready() -> void:
	super()

	_reason_label = UITheme.wrapped_label("", 16, UITheme.PARCHMENT, 420.0)
	content.add_child(_reason_label)

	content.add_child(HSeparator.new())

	var buttons := UITheme.row(10)
	content.add_child(buttons)

	var new_game := UITheme.button("Nová hra", Vector2(190, 40))
	new_game.pressed.connect(func() -> void:
		close()
		GameState.start_new_game(SaveOverlay.NEW_GAME_SEED)
		GameState.notify("Nová hra. Vítejte v Dustfallu.", "success")
	)
	buttons.add_child(new_game)

	var load_game := UITheme.button("Načíst hru", Vector2(190, 40))
	load_game.pressed.connect(func() -> void:
		close()
		load_requested.emit()
	)
	buttons.add_child(load_game)


func refresh() -> void:
	var reason := GameState.game_over_reason
	if GameState.is_victorious:
		set_title("VÍTĚZSTVÍ")
		_reason_label.text = reason if not reason.is_empty() else "Harlan-Voss byl vyhnán z Nevady."
	else:
		set_title("KONEC HRY")
		_reason_label.text = reason if not reason.is_empty() else "Vaše impérium v Nevadě padlo."
