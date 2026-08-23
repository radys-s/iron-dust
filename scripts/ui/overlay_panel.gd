class_name OverlayPanel
extends PanelContainer

## Base for the centred modal panels (tech tree, stavby, obchod, uložení).
##
## Handles the frame — title bar, close button, content column — so each overlay
## only has to fill `content` and implement refresh().

signal closed()

var content: VBoxContainer

var _title_label: Label


func _ready() -> void:
	add_theme_stylebox_override(
		"panel", UITheme.panel_style(UITheme.OVERLAY_BG, UITheme.GOLD, 0.6, 16)
	)
	hide()

	var column := UITheme.column(10)
	add_child(column)

	var header := UITheme.row()
	column.add_child(header)

	_title_label = UITheme.heading("", 24)
	header.add_child(_title_label)
	header.add_child(UITheme.spacer())

	var close_button := UITheme.button("✕  [Esc]")
	close_button.pressed.connect(close)
	header.add_child(close_button)

	column.add_child(HSeparator.new())

	content = UITheme.column(8)
	column.add_child(content)


func set_title(text: String) -> void:
	_title_label.text = text


func open() -> void:
	refresh()
	show()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Overridden by each panel; called every time the overlay is shown and whenever
## the state it displays changes while it is open.
func refresh() -> void:
	pass


## Convenience for panels that rebuild their body from scratch.
func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
