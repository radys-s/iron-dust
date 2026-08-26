class_name AppConfig
extends RefCounted

## Nastaveni aplikace, ktere prezije restart, ale NENI soucasti rozehrane hry.
##
## Zamerne oddelene od save slotu: jestli uz hrac videl tutorial, je vlastnost
## instalace, ne konkretni partie. Kdyby to bylo v save souboru, po smazani
## slotu by se tutorial vnucoval znovu, a naopak by ho nacteni stare hry mohlo
## nechat probehnout podruhe.
##
## Soubor je maly a cely se prepisuje najednou — zadne slucovani, zadna migrace.
## Kdyz se nepodari precist, vrati se vychozi hodnoty a hra bezi dal; nastaveni
## nikdy nesmi byt duvod, proc se hra nespusti.

const PATH := "user://irondust_config.json"

const DEFAULTS := {
	# Prvni spusteni ma jiny tok: Hrat skoci rovnou do Beginner s tutorialem.
	"seen_intro": false,
	# Posledni volba, aby menu nabidlo to, co hrac hraje.
	"last_mode": "beginner",
}


static func load_config() -> Dictionary:
	var config := DEFAULTS.duplicate()
	if not FileAccess.file_exists(PATH):
		return config

	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_warning("Nastaveni nelze precist, pouzivam vychozi.")
		return config

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Nastaveni neni platny JSON, pouzivam vychozi.")
		return config

	# Cte se jen to, co je ve vychozich — neznamy klic ze starsi nebo novejsi
	# verze se tise zahodi misto aby se protahl do hry.
	for key in DEFAULTS:
		if parsed.has(key):
			config[key] = parsed[key]
	return config


static func save_config(config: Dictionary) -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Nastaveni nelze ulozit: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(config, "\t"))
	file.close()
	return true


## Nastavi jeden klic a rovnou zapise. Volani je vzacne (konec tutorialu,
## zmena modu), takze se nevyplati resit davkovani.
static func set_value(key: String, value) -> void:
	var config := load_config()
	config[key] = value
	save_config(config)


static func get_value(key: String):
	return load_config().get(key, DEFAULTS.get(key))
