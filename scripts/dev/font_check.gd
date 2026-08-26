extends SceneTree

## Hlida stazene fonty a jednu past, ktera uz jednou stala hodinu.
##
## Bitter je VARIABILNI font. `FontVariation.variation_opentype` se musi
## adresovat CELOCISELNYM tagem osy — retezcovy klic {"wght": 700} Godot tise
## ignoruje a vykresli zakladni instanci, coz je u Bitteru Thin (100). Vysledek
## je nectitelne tenke UI a zadna chybova hlaska. Test proto overuje, ze
## `name_to_tag("weight")` sedi na tag, ktery font sam hlasi.
##
## Merenim vahu overit nejde: get_string_size() variace nezohlednuje a vraci
## stejnou sirku pro 100 i 900 (overeno). Vizualni kontrola je
## scenes/dev/font_sample.tscn.
##
## godot --headless --path . --script res://scripts/dev/font_check.gd

const EXPECTED_CHECKS := 8
const DISPLAY_FONT := "res://assets/fonts/Rye-Regular.ttf"
const BODY_FONT := "res://assets/fonts/Bitter.ttf"
## Cestina i cislice — obojí musi font pokryt, jinak se to poznama az ve hre.
const SAMPLE := "Dustfall — příliš žluťoučký kůň 0123456789"

var _failures := 0
var _ran := 0


func _initialize() -> void:
	print("\n[1] Fonty se nacitaji a kresli")
	var display := load(DISPLAY_FONT) as FontFile
	var body := load(BODY_FONT) as FontFile
	_check("nadpisovy font se nacetl", display != null, true)
	_check("textovy font se nacetl", body != null, true)

	if display == null or body == null:
		_finish()
		return

	_check("nadpisovy font vykresli cestinu i cislice",
		display.get_string_size(SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > 0.0, true)
	_check("textovy font vykresli cestinu i cislice",
		body.get_string_size(SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > 0.0, true)

	print("\n[2] Variabilni osa vahy")
	var axes := body.get_supported_variation_list()
	var weight_tag := TextServerManager.get_primary_interface().name_to_tag("weight")
	_check("textovy font hlasi osu vahy", axes.has(weight_tag), true)

	if axes.has(weight_tag):
		var span: Vector3i = axes[weight_tag]
		_check("osa vahy zacina na 100", span.x, 100)
		_check("osa vahy konci na 900", span.y, 900)
		# Prave tohle je ta past: font ma jako vychozi instanci Thin, takze
		# kdyz se osa neaplikuje, cele UI je tence a nikdo to nenahlasi.
		_check("vychozi instance je tenka (proto se osa MUSI nastavovat)",
			span.z < 400, true)

	_finish()


func _finish() -> void:
	print("")
	if _ran < EXPECTED_CHECKS:
		print("SELHALO: probehlo jen %d z %d kontrol (nekde spadl runtime error)" % [_ran, EXPECTED_CHECKS])
		quit(1)
		return
	if _failures > 0:
		print("SELHALO: %d z %d kontrol" % [_failures, _ran])
		quit(1)
		return
	print("VSE OK (%d kontrol)" % _ran)
	quit(0)


func _check(label: String, actual, expected) -> void:
	_ran += 1
	if actual == expected:
		print("  ok   %-52s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL %-52s = %s (cekano %s)" % [label, actual, expected])
