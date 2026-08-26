extends Control

## Vizualni kontrola stazenych fontu: ceske znaky, cislice a variabilni vahy.
## Merenim to overit nejde (get_string_size variace ignoruje), takze se to musi
## opravdu vykreslit.

const SAMPLE := "Dustfall 1872 — příliš žluťoučký kůň 0123456789 +29 −14"


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.075, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.position = Vector2(40, 30)
	add_child(column)

	var rye := load("res://assets/fonts/Rye-Regular.ttf")
	column.add_child(_line("RYE 34 — IRON DUST · DUSTFALL", rye, 34))
	column.add_child(_line("Rye 20 — příliš žluťoučký kůň", rye, 20))

	var bitter := load("res://assets/fonts/Bitter.ttf")
	for weight in [300, 400, 600, 700, 900]:
		var variation := FontVariation.new()
		variation.base_font = bitter
		# Osa se adresuje celociselnym tagem, ne retezcem — retezcovy klic Godot tise ignoruje.
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
		column.add_child(_line("Bitter wght %d — %s" % [weight, SAMPLE], variation, 19))


func _line(text: String, font: Font, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.95, 0.89, 0.74))
	return label
